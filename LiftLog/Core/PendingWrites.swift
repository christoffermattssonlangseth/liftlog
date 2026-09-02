import Foundation

/// A change that couldn't reach GitHub yet — captured locally so it survives an
/// offline gym session (or a background kill) and replays on the next reconnect.
///
/// It records exactly what the sync path needs to redo the merge-on-write against
/// the then-current remote file: the operation, its date, and the commit message.
struct PendingWrite: Codable, Identifiable, Equatable {
    /// What to do to the given date's session on replay.
    enum Operation: Codable, Equatable {
        case upsert(ExerciseEntry)     // add or replace an exercise
        case delete(name: String)      // remove an exercise (and the day if it empties)
    }

    var id = UUID()
    var operation: Operation
    var date: Date
    var message: String

    /// Convenience for the common add/replace case.
    init(entry: ExerciseEntry, date: Date, message: String) {
        self.operation = .upsert(entry)
        self.date = date
        self.message = message
    }

    init(operation: Operation, date: Date, message: String) {
        self.operation = operation
        self.date = date
        self.message = message
    }

    /// The exercise name this write concerns — for showing the queue in the UI.
    var exerciseName: String {
        switch operation {
        case .upsert(let entry): return entry.name
        case .delete(let name): return name
        }
    }
}

extension WorkoutParser {

    /// Insert or replace an exercise entry within a session array, keyed by date
    /// + case-insensitive name. Re-logging the same exercise on a day *replaces*
    /// it — that's deliberate: the Session UI treats a second log as "update this
    /// exercise", not a separate block.
    static func merge(_ entry: ExerciseEntry, on date: Date, into base: inout [Session]) {
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

    /// Remove an exercise from a day (case-insensitive). Drops the whole session if
    /// it becomes empty. A no-op if the date or exercise isn't present.
    static func remove(_ name: String, on date: Date, from base: inout [Session]) {
        let key = Session.dateFormatter.string(from: date)
        guard let idx = base.firstIndex(where: { $0.dateString == key }) else { return }
        base[idx].exercises.removeAll { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        if base[idx].exercises.isEmpty { base.remove(at: idx) }
    }

    /// Apply one pending write to a session array.
    static func apply(_ write: PendingWrite, to base: inout [Session]) {
        switch write.operation {
        case .upsert(let entry): merge(entry, on: write.date, into: &base)
        case .delete(let name): remove(name, on: write.date, from: &base)
        }
    }

    /// Replay a queue of pending writes on top of a base set of sessions, in order.
    /// Used both to show queued-but-unsynced changes in the UI and to reconstruct
    /// state from the local cache while offline.
    static func applying(_ writes: [PendingWrite], to sessions: [Session]) -> [Session] {
        var base = sessions
        for write in writes { apply(write, to: &base) }
        return base
    }
}
