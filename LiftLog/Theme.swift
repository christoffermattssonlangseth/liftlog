import SwiftUI

/// Central visual style. Bold, gym-friendly: one strong accent, chunky shapes,
/// large type. Change `accent` here to re-skin the whole app.
enum Theme {
    /// Vivid orange — high-energy, reads well in light and dark.
    static let accent = Color(red: 1.0, green: 0.42, blue: 0.13)

    static let corner: CGFloat = 18
    static let bigFieldHeight: CGFloat = 76

    /// Turn a stored kebab-case name into a bold display label, e.g.
    /// "over-head-press" -> "OVER HEAD PRESS".
    static func displayName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ").uppercased()
    }

    /// Like `displayName` but keeps the original casing — e.g.
    /// "over-head-press" -> "over head press". Used where all-caps reads too shouty.
    static func readableName(_ raw: String) -> String {
        raw.replacingOccurrences(of: "-", with: " ")
    }
}
