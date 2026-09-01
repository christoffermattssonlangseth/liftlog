import Foundation
import SwiftUI
import Combine

/// App-wide state: config, the loaded sessions, and sync with GitHub.
@MainActor
final class Store: ObservableObject {
    // Config (token lives in Keychain, everything else in UserDefaults).
    @AppStorage("gh_owner") var owner = ""
    @AppStorage("gh_repo") var repo = ""
    @AppStorage("gh_path") var path = "training.md"
    @AppStorage("gh_branch") var branch = "main"

    @Published var token: String = Keychain.get(account: "token") ?? ""

    @Published private(set) var sessions: [Session] = []
    @Published private(set) var fileSHA: String?
    @Published var status: String = ""
    @Published var isBusy = false

    func saveToken() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        token = trimmed
        if trimmed.isEmpty { Keychain.delete(account: "token") }
        else { Keychain.set(trimmed, account: "token") }
    }

    private var service: GitHubService {
        GitHubService(owner: owner, repo: repo, path: path, branch: branch, token: token)
    }

    /// Unique exercise names seen in history, for the picker (most recent first).
    var knownExercises: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            for ex in session.exercises where !seen.contains(ex.name.lowercased()) {
                seen.insert(ex.name.lowercased())
                result.append(ex.name)
            }
        }
        return result
    }

    func load() async {
        isBusy = true; status = "Loading…"
        defer { isBusy = false }
        do {
            if let state = try await service.fetch() {
                sessions = WorkoutParser.parse(state.content)
                fileSHA = state.sha
                status = "Loaded \(sessions.count) sessions."
            } else {
                sessions = []
                fileSHA = nil
                status = "No file yet — first save will create it."
            }
        } catch {
            status = error.localizedDescription
        }
    }

    /// Add/replace an exercise entry by merging it into the CURRENT remote file,
    /// never by overwriting with stale in-memory state. This guarantees a save can
    /// never drop history that exists on GitHub, even if the app hasn't loaded it yet.
    func commit(_ entry: ExerciseEntry, on date: Date, message: String) async {
        isBusy = true; status = "Saving…"
        defer { isBusy = false }

        // Retry on 409 conflicts: GitHub can briefly hand back a stale SHA after a
        // recent write, so we re-fetch and re-merge rather than failing the save.
        let maxAttempts = 4
        for attempt in 1...maxAttempts {
            do {
                let remote = try await service.fetch()
                var base = remote.map { WorkoutParser.parse($0.content) } ?? []

                // Safety net: refuse to shrink a non-trivial file down to almost nothing.
                let existingLines = remote?.content
                    .split(separator: "\n")
                    .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                    .count ?? 0
                if existingLines > 1 && base.isEmpty {
                    status = "Aborted: couldn't parse remote file safely."
                    return
                }

                merge(entry, on: date, into: &base)

                let content = WorkoutParser.serialize(base)
                try await service.put(content: content, sha: remote?.sha, message: message)

                sessions = base
                fileSHA = remote?.sha
                status = "Pushed ✓"
                return
            } catch let error as GitHubService.GitHubError {
                if case .badResponse(409, _) = error, attempt < maxAttempts {
                    status = "Syncing… (retry \(attempt))"
                    try? await Task.sleep(nanoseconds: 700_000_000)  // 0.7s back-off
                    continue
                }
                status = error.localizedDescription
                return
            } catch {
                status = error.localizedDescription
                return
            }
        }
    }

    /// Insert/replace an entry inside an arbitrary session array (used for merge-on-write).
    private func merge(_ entry: ExerciseEntry, on date: Date, into base: inout [Session]) {
        let key = Session.dateFormatter.string(from: date)
        if let idx = base.firstIndex(where: { $0.dateString == key }) {
            if let exIdx = base[idx].exercises.firstIndex(where: {
                $0.name.caseInsensitiveCompare(entry.name) == .orderedSame
            }) {
                base[idx].exercises[exIdx] = entry
            } else {
                base[idx].exercises.append(entry)
            }
        } else {
            base.append(Session(date: date, exercises: [entry]))
            base.sort { $0.date < $1.date }
        }
    }

    func lastEntry(for name: String, before date: Date) -> ExerciseEntry? {
        WorkoutParser.lastEntry(for: name, in: sessions, before: date)
    }
}
