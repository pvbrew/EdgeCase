import Foundation
@testable import EdgeCaseExample

extension User {
    /// Stand-in for a fixtures-style library: one realistic instance, the
    /// kind a `.fixture()` factory or builder would produce. EdgeCase
    /// composes adversarial values around it with `edgeCases(varying:)`.
    static func fixture(
        username: String = "ada_lovelace",
        age: Int = 36,
        karma: Double = 1_815.12,
        bio: String? = "Analyst, first programmer.",
        tags: [String] = ["maths", "engines"]
    ) -> User {
        User(
            id: 1,
            username: username,
            age: age,
            karma: karma,
            isVerified: true,
            bio: bio,
            tags: tags,
            address: Address(city: "London", zipCode: 10_178),
            membership: .pro(renewsInDays: 30),
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000),
            website: URL(string: "https://example.org/ada"),
            avatarSystemName: "person.crop.circle.badge.checkmark"
        )
    }
}
