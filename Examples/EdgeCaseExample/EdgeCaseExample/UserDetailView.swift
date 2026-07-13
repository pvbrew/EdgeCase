import SwiftUI

/// Renders one adversarial instance the way a profile screen would —
/// the interesting part is watching it stay usable for Int.min ids,
/// 10,000-character usernames, and NaN karma.
struct UserDetailView: View {
    let user: User

    var body: some View {
        List {
            Section("Rendered") {
                LabeledContent("Display name", value: user.displayName)
                LabeledContent("Karma", value: user.formattedKarma)
                LabeledContent("Verified", value: user.isVerified ? "Yes" : "No")
            }
            Section("Raw values") {
                LabeledContent("id", value: String(user.id))
                LabeledContent("username", value: "\(user.username.count) character\(user.username.count == 1 ? "" : "s")")
                LabeledContent("karma", value: String(user.karma))
                LabeledContent("isVerified", value: String(user.isVerified))
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
                karma: .nan,
                isVerified: false
            )
        )
    }
}
