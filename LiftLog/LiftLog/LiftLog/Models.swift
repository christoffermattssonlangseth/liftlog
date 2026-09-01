import Foundation

/// One set within an exercise. Weight is nil for bodyweight movements (chin-ups etc.).
struct WorkSet: Identifiable, Equatable, Codable {
    var id = UUID()
    var weight: Double?   // nil => bodyweight ("bw")
    var reps: Int

    var isBodyweight: Bool { weight == nil }

    /// Serialize to the training.md token, e.g. "46.5x8" or "bwx3".
    var token: String {
        let w = weight.map(WorkSet.formatWeight) ?? "bw"
        return "\(w)x\(reps)"
    }

    static func formatWeight(_ w: Double) -> String {
        if w == w.rounded() { return String(Int(w)) }
        return String(w)
    }
}

/// One exercise line: a name plus its sets.
struct ExerciseEntry: Identifiable, Equatable, Codable {
    var id = UUID()
    var name: String
    var sets: [WorkSet]

    func line(date: String) -> String {
        let setStr = sets.map(\.token).joined(separator: " ")
        return "\(date) \(name) \(setStr)"
    }
}

/// All the exercises logged on one calendar date.
struct Session: Identifiable, Equatable, Codable {
    var id = UUID()
    var date: Date
    var exercises: [ExerciseEntry]

    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    var dateString: String { Session.dateFormatter.string(from: date) }
}
