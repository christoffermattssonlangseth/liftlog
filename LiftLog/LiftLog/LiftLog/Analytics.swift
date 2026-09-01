import Foundation

/// A single point on a progression chart.
struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// The change between two points on a series.
struct TrendChange {
    let delta: Double
    let percent: Double
    var isUp: Bool { delta >= 0 }
}

/// Progression metrics derived from the logged sessions. Purely lift-focused —
/// no personal targets, just how each movement is trending.
enum Analytics {
    enum Metric: String, CaseIterable, Identifiable {
        case topSet = "Top set"      // heaviest weight lifted — the direct intensity signal
        case oneRepMax = "Est. 1RM"  // derived, for comparing across rep schemes
        case maxReps = "Max reps"    // for bodyweight lifts, where reps are the progression
        var id: String { rawValue }

        var unit: String {
            switch self {
            case .topSet, .oneRepMax: return "kg"
            case .maxReps: return "reps"
            }
        }
    }

    /// Epley estimated one-rep max.
    static func epley(weight: Double, reps: Int) -> Double {
        weight * (1 + Double(reps) / 30)
    }

    /// All sets ever logged for an exercise.
    static func allSets(_ name: String, in sessions: [Session]) -> [WorkSet] {
        sessions.flatMap { session in
            session.exercises
                .filter { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                .flatMap(\.sets)
        }
    }

    /// A lift with no weighted sets (e.g. pull-ups) — 1RM/top-set don't apply.
    static func isBodyweight(_ name: String, in sessions: [Session]) -> Bool {
        let sets = allSets(name, in: sessions)
        return !sets.isEmpty && sets.allSatisfy(\.isBodyweight)
    }

    /// Metrics that make sense for this exercise. Weighted lifts lead with top-set
    /// weight (intensity); bodyweight lifts progress by reps.
    static func availableMetrics(_ name: String, in sessions: [Session]) -> [Metric] {
        isBodyweight(name, in: sessions) ? [.maxReps] : [.topSet, .oneRepMax]
    }

    /// One value per session date for the chosen metric.
    static func series(_ name: String, metric: Metric, in sessions: [Session]) -> [TrendPoint] {
        sessions.compactMap { session -> TrendPoint? in
            guard let ex = session.exercises.first(where: {
                $0.name.caseInsensitiveCompare(name) == .orderedSame
            }) else { return nil }

            let value: Double?
            switch metric {
            case .topSet:
                value = ex.sets.compactMap(\.weight).max()
            case .oneRepMax:
                value = ex.sets.compactMap { set in
                    set.weight.map { epley(weight: $0, reps: set.reps) }
                }.max()
            case .maxReps:
                value = ex.sets.map { Double($0.reps) }.max()
            }
            return value.map { TrendPoint(date: session.date, value: $0) }
        }
        .sorted { $0.date < $1.date }
    }

    /// Change from the earliest point (long-term). `sinceDays` limits the window (short-term).
    static func change(_ series: [TrendPoint], sinceDays days: Int? = nil) -> TrendChange? {
        guard let last = series.last, series.count >= 2 else { return nil }
        let start: TrendPoint?
        if let days {
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: last.date) ?? last.date
            start = series.first { $0.date >= cutoff }
        } else {
            start = series.first
        }
        guard let s = start, s.date < last.date else { return nil }
        let delta = last.value - s.value
        let percent = s.value == 0 ? 0 : delta / s.value * 100
        return TrendChange(delta: delta, percent: percent)
    }
}
