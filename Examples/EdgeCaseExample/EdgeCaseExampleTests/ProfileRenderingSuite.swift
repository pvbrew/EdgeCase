import EdgeCase
import EdgeCaseTesting
import Foundation
import Testing
@testable import EdgeCaseExample

// The swift-testing workflow: parameterized tests consume generated edge
// cases directly — one test *case* per instance in the navigator, so a
// failure names the exact adversarial value instead of an index in a loop.

@Suite("Profile rendering (swift-testing)")
struct ProfileRenderingSuite {

    // `edgeCases` is a plain `[User]`, so it feeds `arguments:` as-is.
    @Test(arguments: User.edgeCases)
    func everyDerivedFieldRenders(_ user: User) {
        #expect(!user.displayName.isEmpty)
        #expect(user.displayName.count <= 24)
        #expect(!user.formattedKarma.isEmpty)
        #expect(!user.bioPreview.isEmpty)
        #expect(user.bioPreview.count <= 40)
        #expect(!user.tagSummary.isEmpty)
        #expect(!user.membershipLabel.isEmpty)
        #expect(!user.memberSince.isEmpty)
        #expect(!user.websiteLabel.isEmpty)
    }

    // `labeledEdgeCases` (from EdgeCaseTesting) shows "[3] User(id: 92233…"
    // in the navigator instead of a 10,000-character description.
    @Test(arguments: User.labeledEdgeCases)
    func cardExportSurvives(_ edgeCase: LabeledEdgeCase<User>) throws {
        let data = try edgeCase.value.exportCard()
        #expect(!data.isEmpty)
    }
}

@Suite("Fixture composition")
struct FixtureCompositionSuite {

    // The fixtures integration point: every argument keeps the realistic
    // fixture's values except one property carrying an edge case —
    // `labeledEdgeCases(varying:)` adds the short navigator labels on top.
    @Test(arguments: User.labeledEdgeCases(varying: .fixture()))
    func renderingSurvivesOneAdversaryInARealisticProfile(_ edgeCase: LabeledEdgeCase<User>) throws {
        let user = edgeCase.value
        #expect(!user.displayName.isEmpty)
        #expect(!user.formattedKarma.isEmpty)
        _ = try user.exportCard()
    }

    @Test func composedCasesKeepTheFixtureRealistic() {
        let fixture = User.fixture()
        let composed = User.edgeCases(varying: fixture)

        // The excluded avatar keeps the fixture's custom value — plain
        // generation would have reapplied the "person.crop.circle" default.
        #expect(composed.allSatisfy { $0.avatarSystemName == fixture.avatarSystemName })

        // One adversary at a time: the huge-username case keeps Ada's karma.
        let hugeUsername = composed.first { $0.username.count == 10_000 }
        #expect(hugeUsername?.karma == fixture.karma)
        #expect(hugeUsername?.bio == fixture.bio)

        // Age still respects its custom domain, or holds the fixture's value.
        #expect(Set(composed.map(\.age)).isSubset(of: [0, 13, 118, fixture.age]))
    }
}
