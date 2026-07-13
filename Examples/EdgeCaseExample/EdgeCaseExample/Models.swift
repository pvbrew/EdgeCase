import EdgeCase
import Foundation

/// The kind of model you'd ship in a real app. `@EdgeCases` generates
/// `User.edgeCases` — one instance per boundary value of each property.
///
/// `nonisolated` opts the model out of the app target's default MainActor
/// isolation, so `edgeCases` stays callable from any context — including
/// the unit test target.
@EdgeCases
nonisolated struct User {
    let id: Int
    let username: String
    let karma: Double
    var isVerified: Bool
}

nonisolated extension User {
    /// What the profile header shows — must survive empty, whitespace-only,
    /// and 10,000-character usernames.
    var displayName: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "anonymous" : String(trimmed.prefix(24))
    }

    /// Karma as displayed on the profile — must survive `.nan` and `.infinity`.
    var formattedKarma: String {
        guard karma.isFinite else { return "—" }
        return karma.formatted(.number.precision(.fractionLength(0...1)))
    }
}
