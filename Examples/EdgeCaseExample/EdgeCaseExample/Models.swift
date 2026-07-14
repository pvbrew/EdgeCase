import EdgeCase
import Foundation

/// The kind of model you'd ship in a real app — now with the v0.2 shapes
/// that cause real-world crashes: an optional, an array, a nested custom
/// type, and an enum. `@EdgeCases` generates `User.edgeCases` — one instance
/// per boundary value of each property, recursing into `Address` and
/// `Membership` through their own generated `EdgeCaseGeneratable`
/// conformances.
///
/// `nonisolated` opts the models out of the app target's default MainActor
/// isolation, so `edgeCases` stays callable from any context — including
/// the unit test target.
@EdgeCases
nonisolated struct User {
    let id: Int
    let username: String
    let karma: Double
    var isVerified: Bool
    let bio: String?
    let tags: [String]
    let address: Address
    let membership: Membership
}

@EdgeCases
nonisolated struct Address {
    let city: String
    let zipCode: Int
}

@EdgeCases
nonisolated enum Membership: Equatable {
    case free
    case pro(renewsInDays: Int)
}

nonisolated extension User {
    /// What the profile header shows — must survive empty, whitespace-only,
    /// 10,000-character, and combining-diacritic usernames.
    var displayName: String {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "anonymous" : String(trimmed.prefix(24))
    }

    /// Karma as displayed on the profile — must survive `.nan` and `.infinity`.
    var formattedKarma: String {
        guard karma.isFinite else { return "—" }
        return karma.formatted(.number.precision(.fractionLength(0...1)))
    }

    /// One-line bio teaser — must survive `nil`, emoji, right-to-left text,
    /// and 10,000 characters.
    var bioPreview: String {
        guard let bio else { return "No bio yet" }
        let trimmed = bio.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No bio yet" : String(trimmed.prefix(40))
    }

    /// Tag chips summary — must survive empty and 1,000-element arrays.
    var tagSummary: String {
        guard !tags.isEmpty else { return "No tags" }
        let shown = tags.prefix(2).map { tag in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "untagged" : String(trimmed.prefix(12))
        }
        let remainder = tags.count - shown.count
        return remainder > 0 ? shown.joined(separator: ", ") + " +\(remainder) more" : shown.joined(separator: ", ")
    }

    /// Badge text — must make sense for `.pro` with `Int.min` days left.
    var membershipLabel: String {
        switch membership {
        case .free:
            return "Free"
        case .pro(let renewsInDays):
            return renewsInDays >= 0 ? "Pro · renews in \(renewsInDays)d" : "Pro · expired"
        }
    }
}

nonisolated extension Address {
    /// Must survive empty, whitespace-only, and unicode city names.
    var displayCity: String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown city" : String(trimmed.prefix(24))
    }
}
