import SwiftUI

/// Renders one adversarial instance the way a profile screen would —
/// the interesting part is watching it stay usable for Int.min ids,
/// 10,000-character usernames, NaN karma, nil bios, 1,000-tag arrays,
/// right-to-left city names, distant-past join dates, and file:// websites.
struct UserDetailView: View {
    let user: User

    var body: some View {
        List {
            Section("Rendered") {
                LabeledContent("Display name", value: user.displayName)
                LabeledContent("Audience", value: user.audienceBadge)
                LabeledContent("Karma", value: user.formattedKarma)
                LabeledContent("Verified", value: user.isVerified ? "Yes" : "No")
                LabeledContent("Bio", value: user.bioPreview)
                LabeledContent("Tags", value: user.tagSummary)
                LabeledContent("City", value: user.address.displayCity)
                LabeledContent("Membership", value: user.membershipLabel)
                LabeledContent("Member since", value: user.memberSince)
                LabeledContent("Website", value: user.websiteLabel)
                LabeledContent("Avatar") {
                    // Held at its default by @EdgeCase(.exclude) — varying a
                    // cosmetic asset name would only add noise.
                    Image(systemName: user.avatarSystemName)
                }
            }
            Section("Raw values") {
                LabeledContent("id", value: String(user.id))
                LabeledContent("username", value: "\(user.username.count) character\(user.username.count == 1 ? "" : "s")")
                LabeledContent("age", value: String(user.age))
                LabeledContent("karma", value: String(user.karma))
                LabeledContent("isVerified", value: String(user.isVerified))
                LabeledContent("bio", value: user.bio.map { "\($0.count) character\($0.count == 1 ? "" : "s")" } ?? "nil")
                LabeledContent("tags", value: "\(user.tags.count) element\(user.tags.count == 1 ? "" : "s")")
                LabeledContent("address.zipCode", value: String(user.address.zipCode))
                LabeledContent("joinedAt", value: String(user.joinedAt.timeIntervalSince1970))
                LabeledContent("website", value: user.website.map { "\($0.absoluteString.count) character\($0.absoluteString.count == 1 ? "" : "s")" } ?? "nil")
            }
        }
        .navigationTitle(user.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Macro-introduced names like `edgeCases` can't be referenced inside another
// macro's arguments (#Preview's closure), so this preview builds its own
// adversarial instance.
#Preview {
    NavigationStack {
        UserDetailView(
            user: User(
                id: .max,
                username: String(repeating: "a", count: 10_000),
                age: 13,
                karma: .nan,
                isVerified: false,
                bio: nil,
                tags: ["swift", " ", "macros"],
                address: Address(city: "Cafe\u{0301} City", zipCode: .max),
                membership: .pro(renewsInDays: .min),
                joinedAt: .distantFuture,
                website: URL(string: "a")
            )
        )
    }
}
