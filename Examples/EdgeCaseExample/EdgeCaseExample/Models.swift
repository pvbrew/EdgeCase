import EdgeCase
import Foundation

/// The kind of model you'd ship in a real app, with the shapes that make
/// the macro usable on real domain models:
///
/// - `@EdgeCase(.custom([...]))` keeps `age` inside its real domain (and
///   lands exactly on the age-gate boundary) instead of `Int.min`/`Int.max`.
/// - `@EdgeCase(.exclude)` pins `avatarSystemName` to its default — varying
///   a cosmetic asset name would only add noise.
/// - `joinedAt: Date` and `website: URL?` join generation through the
///   `EdgeCaseGeneratable` conformances that ship with EdgeCase.
///
/// `nonisolated` opts the models out of the app target's default MainActor
/// isolation, so `edgeCases` stays callable from any context — including
/// the unit test target.
@EdgeCases
nonisolated struct User {
    let id: Int
    let username: String
    @EdgeCase(.custom([0, 13, 118]))
    let age: Int
    let karma: Double
    var isVerified: Bool
    let bio: String?
    let tags: [String]
    let address: Address
    let membership: Membership
    let joinedAt: Date
    let website: URL?
    @EdgeCase(.exclude)
    var avatarSystemName: String = "person.crop.circle"
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

    /// Age-gate badge — the custom override generates 0, 13, and 118, so the
    /// gate is tested exactly on its boundary instead of at `Int.min`.
    var audienceBadge: String {
        switch age {
        case ..<13: "Kids"
        case 13 ..< 18: "Teen"
        default: "Adult"
        }
    }

    /// Member-since line — must survive `.distantPast`, `.distantFuture`,
    /// and the 32-bit rollover date.
    var memberSince: String {
        "Joined \(joinedAt.formatted(.dateTime.year()))"
    }

    /// Website chip — must survive `nil`, a scheme-less single character, a
    /// 2,000-character path, and file URLs.
    var websiteLabel: String {
        guard let website else { return "No website" }
        let label = website.host() ?? website.absoluteString
        return String(label.prefix(24))
    }
}

nonisolated extension Address {
    /// Must survive empty, whitespace-only, and unicode city names.
    var displayCity: String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unknown city" : String(trimmed.prefix(24))
    }
}

/// The share-sheet payload — a throwing surface for
/// `XCTAssertNoThrow(forEachEdgeCase:)` to guard.
nonisolated struct ProfileCard: Codable {
    let name: String
    let karma: String
    let city: String
}

nonisolated extension User {
    /// Serializes the profile for sharing. Encoding the raw `karma: Double`
    /// would throw for `.nan` and `.infinity` (JSON has no representation
    /// for them) — encoding the formatted string survives every edge case.
    func exportCard() throws -> Data {
        try JSONEncoder().encode(
            ProfileCard(name: displayName, karma: formattedKarma, city: address.displayCity)
        )
    }
}
