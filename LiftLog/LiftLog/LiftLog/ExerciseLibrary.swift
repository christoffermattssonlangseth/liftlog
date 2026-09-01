import Foundation

/// A built-in catalog of common lifts (kebab-case to match the training.md style).
/// Users can still type any name that isn't in this list.
enum ExerciseLibrary {
    static let all: [String] = [
        // Legs
        "squat", "front-squat", "romanian-deadlift", "deadlift",
        "leg-press", "leg-curl", "leg-extension", "lunge", "hip-thrust", "calf-raise",
        // Push
        "bench-press", "incline-bench-press", "close-grip-bench-press",
        "over-head-press", "dips", "tricep-pushdown", "lateral-raise",
        // Pull
        "barbell-row", "seal-row", "upright-row", "pull-ups", "chin-ups",
        "lat-pulldown", "face-pull", "dumbbell-curl", "hammer-curl",
        // Core
        "plank", "hanging-leg-raise",
    ]
}
