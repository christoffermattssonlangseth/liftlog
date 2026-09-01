import Foundation

/// Talks to the GitHub Contents API to read and update a single file
/// (your training.md). Uses a fine-grained personal access token with
/// "Contents: Read and write" permission on the one repo.
struct GitHubService {
    var owner: String
    var repo: String
    var path: String
    var branch: String
    var token: String

    struct FileState {
        var content: String
        var sha: String
    }

    enum GitHubError: LocalizedError {
        case badResponse(Int, String)
        case missingConfig
        case decoding

        var errorDescription: String? {
            switch self {
            case .badResponse(let code, let body): return "GitHub \(code): \(body)"
            case .missingConfig: return "Fill in owner, repo, path and token in Settings."
            case .decoding: return "Couldn't read GitHub's response."
            }
        }
    }

    private var contentsURL: URL {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/contents/\(path)")!
    }

    private func authorized(_ request: inout URLRequest) {
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
    }

    func validated() throws {
        guard !owner.isEmpty, !repo.isEmpty, !path.isEmpty, !token.isEmpty else {
            throw GitHubError.missingConfig
        }
    }

    /// Fetch current file content + sha. Returns nil content only if file is missing (404).
    func fetch() async throws -> FileState? {
        try validated()
        var comps = URLComponents(url: contentsURL, resolvingAgainstBaseURL: false)!
        comps.queryItems = [URLQueryItem(name: "ref", value: branch)]
        var request = URLRequest(url: comps.url!)
        authorized(&request)
        // Never serve a stale SHA from cache — that causes 409 conflicts on the next PUT.
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubError.badResponse(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sha = json["sha"] as? String,
              let base64 = json["content"] as? String else {
            throw GitHubError.decoding
        }
        let cleaned = base64.replacingOccurrences(of: "\n", with: "")
        let content = Data(base64Encoded: cleaned).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return FileState(content: content, sha: sha)
    }

    /// Create or update the file. Pass the sha from a prior fetch to update; nil to create.
    func put(content: String, sha: String?, message: String) async throws {
        try validated()
        var request = URLRequest(url: contentsURL)
        request.httpMethod = "PUT"
        authorized(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "message": message,
            "content": Data(content.utf8).base64EncodedString(),
            "branch": branch,
        ]
        if let sha { body["sha"] = sha }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        let http = response as! HTTPURLResponse
        guard (200..<300).contains(http.statusCode) else {
            throw GitHubError.badResponse(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }
    }
}
