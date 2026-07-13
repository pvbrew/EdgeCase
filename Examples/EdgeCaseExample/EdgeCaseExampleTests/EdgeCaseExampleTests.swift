import EdgeCase
import XCTest
@testable import EdgeCaseExample

final class EdgeCaseExampleTests: XCTestCase {

    /// The canonical EdgeCase workflow: run every generated adversarial
    /// instance through the code under test instead of hand-writing fixtures.
    func testDisplayNameSurvivesAllEdgeCases() {
        for user in User.edgeCases {
            let name = user.displayName
            XCTAssertFalse(name.isEmpty, "displayName collapsed to empty for \(user)")
            XCTAssertLessThanOrEqual(name.count, 24, "displayName not truncated for \(user)")
        }
    }

    func testKarmaFormattingSurvivesAllEdgeCases() {
        for user in User.edgeCases {
            XCTAssertFalse(user.formattedKarma.isEmpty, "formattedKarma collapsed to empty for \(user)")
        }
    }

    func testEdgeCasesCoverTheValuesYouForget() {
        XCTAssertTrue(User.edgeCases.contains { $0.id == Int.max })
        XCTAssertTrue(User.edgeCases.contains { $0.username.count == 10_000 })
        XCTAssertTrue(User.edgeCases.contains { $0.karma.isNaN })
    }
}

/// `@EdgeCases` works on test-local fixtures too — no app code required.
@EdgeCases
struct Payload {
    let size: Int32
    let body: String
}

final class TestLocalFixtureTests: XCTestCase {
    func testPayloadFixtureGeneratesCases() {
        XCTAssertFalse(Payload.edgeCases.isEmpty)
        XCTAssertTrue(Payload.edgeCases.contains { $0.size == Int32.min })
    }
}
