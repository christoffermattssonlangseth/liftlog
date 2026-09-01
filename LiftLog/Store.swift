import Foundation
import SwiftUI

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

    /// Add/replace today's exercise entry locally, then push.
    func commit(_ entry: ExerciseEntry, on date: Date, message: String) async {
        upsert(entry, on: date)
        await push(message: message)
    }

    func upsert(_ entry: ExerciseEntry, on date: Date) {
        let key = Session.dateFormatter.string(from: date)
        if let idx = sessions.firstIndex(where: { $0.dateString == key }) {
            if let exIdx = sessions[idx].exercises.firstIndex(where: {
                $0.name.caseInsensitiveCompare(entry.name) == .orderedSame
            }) {
                sessions[idx].exercises[exIdx] = entry
            } else {
                sessions[idx].exercises.append(entry)
            }
        } else {
            sessions.append(Session(date: date, exercises: [entry]))
            sessions.sort { $0.date < $1.date }
        }
    }

    func delete(exerciseID: UUID, sessionID: UUID) {
        guard let sIdx = sessions.firstIndex(where: { $0.id == sessionID }) else { return }
        sessions[sIdx].exercises.removeAll { $0.id == exerciseID }
        if sessions[sIdx].exercises.isEmpty { sessions.remove(at: sIdx) }
    }

    func push(message: String) async {
        isBusy = true; status = "Pushing…"
        defer { isBusy = false }
        do {
            // Re-fetch sha to avoid conflicts if the file changed elsewhere.
            if let latest = try await service.fetch() {
                fileSHA = latest.sha
            }
            let content = WorkoutParser.serialize(sessions)
            try await service.put(content: content, sha: fileSHA, message: message)
            if let latest = try await service.fetch() { fileSHA = latest.sha }
            status = "Pushed ✓"
        } catch {
            status = error.localizedDescription
        }
    }

    func lastEntry(for name: String, before date: Date) -> ExerciseEntry? {
        WorkoutParser.lastEntry(for: name, in: sessions, before: date)
    }
}
