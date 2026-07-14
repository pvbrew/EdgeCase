import EdgeCase
import XCTest
@testable import EdgeCaseExample

final class EdgeCaseExampleTests: XCTestCase {

    /// The canonical EdgeCase workflow: run every generated adversarial
    /// instance through the code under test instead of hand-writing fixtures.
    func testDisplayNameSurvivesAllEdgeCases() {
        for user in User.edgeCases {
            let name = user.displayName
            XCTAssertFalse(name.isEmpty, "displayName collapsed to empty for \(user.id)")
            XCTAssertLessThanOrEqual(name.count, 24, "displayName not truncated for \(user.id)")
        }
    }

    func testKarmaFormattingSurvivesAllEdgeCases() {
        for user in User.edgeCases {
            XCTAssertFalse(user.formattedKarma.isEmpty, "formattedKarma collapsed to empty for karma \(user.karma)")
        }
    }

    func testBioPreviewSurvivesAllEdgeCases() {
        for user in User.edgeCases {
            let preview = user.bioPreview
            XCTAssertFalse(preview.isEmpty, "bioPreview collapsed to empty for bio \(String(describing: user.bio))")
            XCTAssertLessThanOrEqual(preview.count, 40, "bioPreview not truncated")
        }
    }

    func testTagSummarySurvivesAllEdgeCases() {
        for user in User.edgeCases {
            XCTAssertFalse(user.tagSummary.isEmpty, "tagSummary collapsed to empty for \(user.tags.count) tags")
        }
    }

    func testMembershipLabelSurvivesAllEdgeCases() {
        for user in User.edgeCases {
            XCTAssertFalse(user.membershipLabel.isEmpty)
        }
    }

    func testEdgeCasesCoverTheValuesYouForget() {
        // v0.1 primitives.
        XCTAssertTrue(User.edgeCases.contains { $0.id == Int.max })
        XCTAssertTrue(User.edgeCases.contains { $0.username.count == 10_000 })
        XCTAssertTrue(User.edgeCases.contains { $0.karma.isNaN })

        // v0.2: optionals are nil and every wrapped edge case.
        XCTAssertTrue(User.edgeCases.contains { $0.bio == nil })
        XCTAssertTrue(User.edgeCases.contains { $0.bio?.count == 10_000 })

        // v0.2: unicode adversaries — combining diacritics and zero-width characters.
        XCTAssertTrue(User.edgeCases.contains { $0.username.contains("Cafe\u{0301}") })
        XCTAssertTrue(User.edgeCases.contains { $0.username.unicodeScalars.contains("\u{200B}") })

        // v0.2: arrays are empty, single, large, and all-edge-case elements.
        XCTAssertTrue(User.edgeCases.contains { $0.tags.isEmpty })
        XCTAssertTrue(User.edgeCases.contains { $0.tags.count == 1_000 })

        // v0.2: nested types are recursed into.
        XCTAssertTrue(User.edgeCases.contains { $0.address.zipCode == Int.max })
        XCTAssertTrue(User.edgeCases.contains { $0.address.city.count == 10_000 })

        // v0.2: enums cover every case and vary associated values.
        XCTAssertTrue(User.edgeCases.contains { $0.membership == .free })
        XCTAssertTrue(User.edgeCases.contains { $0.membership == .pro(renewsInDays: Int.min) })
    }

    func testCaseCountStaysLinear() {
        // One varied value per instance keeps the set reviewable — the sum of
        // each property's cases, never a cartesian product.
        XCTAssertLessThan(User.edgeCases.count, 60)
    }
}

/// `@EdgeCases` works on test-local fixtures too — no app code required.
@EdgeCases
struct Payload {
    let size: Int32
    let body: String
    let checksum: Int64?
    let chunks: [Int8]
}

final class TestLocalFixtureTests: XCTestCase {
    func testPayloadFixtureGeneratesCases() {
        XCTAssertFalse(Payload.edgeCases.isEmpty)
        XCTAssertTrue(Payload.edgeCases.contains { $0.size == Int32.min })
        XCTAssertTrue(Payload.edgeCases.contains { $0.checksum == nil })
        XCTAssertTrue(Payload.edgeCases.contains { $0.checksum == Int64.max })
        XCTAssertTrue(Payload.edgeCases.contains { $0.chunks == [Int8.min, Int8.max, 0, -1] })
    }
}
