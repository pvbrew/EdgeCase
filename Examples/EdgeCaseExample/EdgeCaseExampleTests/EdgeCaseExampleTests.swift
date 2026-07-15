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

    func testMemberSinceSurvivesAllEdgeCases() {
        // .distantPast, .distantFuture, and the 32-bit rollover all render.
        for user in User.edgeCases {
            XCTAssertFalse(user.memberSince.isEmpty, "memberSince collapsed for \(user.joinedAt)")
        }
    }

    func testWebsiteLabelSurvivesAllEdgeCases() {
        // nil, scheme-less "a", a 2,000-character path, and file:// URLs.
        for user in User.edgeCases {
            let label = user.websiteLabel
            XCTAssertFalse(label.isEmpty, "websiteLabel collapsed for \(String(describing: user.website))")
            XCTAssertLessThanOrEqual(label.count, 24, "websiteLabel not truncated")
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

        // v0.3: Date and URL join in through the bundled conformances.
        XCTAssertTrue(User.edgeCases.contains { $0.joinedAt == .distantPast })
        XCTAssertTrue(User.edgeCases.contains { $0.joinedAt == .distantFuture })
        XCTAssertTrue(User.edgeCases.contains { $0.website == nil })
        XCTAssertTrue(User.edgeCases.contains { $0.website?.isFileURL == true })
    }

    // v0.3: @EdgeCase(.custom([...])) bounds a property to its real domain.
    func testCustomOverrideKeepsAgeInItsDomain() {
        XCTAssertEqual(Set(User.edgeCases.map(\.age)), [0, 13, 118], "age never leaves the overridden domain")
        XCTAssertTrue(User.edgeCases.contains { $0.age == 13 }, "the age-gate boundary itself is generated")
    }

    // v0.3: @EdgeCase(.exclude) pins a property to its default value.
    func testExcludedPropertyNeverVaries() {
        XCTAssertTrue(User.edgeCases.allSatisfy { $0.avatarSystemName == "person.crop.circle" })
    }

    func testCaseCountStaysLinear() {
        // One varied value per instance keeps the set reviewable — the sum of
        // each property's cases (12 properties ≈ 70 instances here), never a
        // cartesian product (which would be astronomically large).
        XCTAssertLessThan(User.edgeCases.count, 100)
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

// MARK: - v0.3 strategies

/// Cross-field validation is where `.combinatorial` earns its keep: every
/// pairing of adversarial username × code, not just one adversary at a time.
@EdgeCases(strategy: .combinatorial)
struct LoginAttempt {
    let username: String
    let oneTimeCode: Int8
}

/// `.minimal` packs every edge value into the fewest instances — the
/// smoke-test set you can afford to run in every build.
@EdgeCases(strategy: .minimal)
struct SearchQuery {
    let text: String
    let limit: Int
    let exactMatch: Bool
}

final class StrategyFixtureTests: XCTestCase {

    private func validate(_ attempt: LoginAttempt) -> Bool {
        !attempt.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && attempt.oneTimeCode >= 0
    }

    func testCombinatorialCoversEveryPairing() {
        // 8 username cases × 4 code cases — the full product.
        XCTAssertEqual(LoginAttempt.edgeCases.count, 8 * 4)
        XCTAssertTrue(
            LoginAttempt.edgeCases.contains { $0.username.count == 10_000 && $0.oneTimeCode == .min },
            "pairings one-at-a-time never produces"
        )
        for attempt in LoginAttempt.edgeCases {
            _ = validate(attempt) // must not trap for any pairing
        }
    }

    func testMinimalIsTheSmallestFullCoverageSet() {
        // As many instances as the longest column (String's 8 cases); Int
        // and Bool cycle, so every edge value still appears.
        XCTAssertEqual(SearchQuery.edgeCases.count, 8)
        XCTAssertEqual(Set(SearchQuery.edgeCases.map(\.limit)), [Int.min, Int.max, 0, -1])
        XCTAssertTrue(SearchQuery.edgeCases.contains { $0.text.count == 10_000 })
    }
}
