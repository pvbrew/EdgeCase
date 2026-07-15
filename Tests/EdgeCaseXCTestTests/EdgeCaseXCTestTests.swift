import EdgeCase
import EdgeCaseXCTest
import XCTest

@EdgeCases
struct Fragment: Equatable {
    let text: String
    let width: Int
}

struct RenderError: Error {
    let reason: String
}

/// Deliberately fragile renderer: chokes on the adversaries EdgeCase
/// generates so the failure path has something to report.
private func render(_ fragment: Fragment) throws {
    if fragment.width < 0 {
        throw RenderError(reason: "negative width")
    }
    if fragment.text.count >= 10_000 {
        throw RenderError(reason: "text too long")
    }
}

final class EdgeCaseXCTestTests: XCTestCase {

    func testPassesWhenNoCaseThrows() {
        // Must record no failure at all.
        XCTAssertNoThrow(forEachEdgeCase: Fragment.self) { _ in }
    }

    func testForEachOverloadCoversExplicitCases() {
        let base = Fragment(text: "hello", width: 320)
        var seen: [Fragment] = []
        XCTAssertNoThrow(forEach: Fragment.edgeCases(varying: base)) { fragment in
            seen.append(fragment)
        }
        XCTAssertEqual(seen, Fragment.edgeCases(varying: base), "every composed case runs through the body")
    }

    // XCTExpectFailure does not exist in swift-corelibs-xctest.
    #if canImport(ObjectiveC)
    func testReportsEveryThrowingCaseAndKeepsIterating() {
        var survivors = 0
        XCTExpectFailure("the fragile renderer throws for several edge cases") {
            XCTAssertNoThrow(forEachEdgeCase: Fragment.self) { fragment in
                try render(fragment)
                survivors += 1
            }
        }
        // Iteration continued past the throwing cases instead of stopping at
        // the first failure.
        let throwing = Fragment.edgeCases.filter { $0.width < 0 || $0.text.count >= 10_000 }.count
        XCTAssertEqual(survivors, Fragment.edgeCases.count - throwing)
        XCTAssertGreaterThan(throwing, 1, "the fixture must exercise more than one failing case")
    }

    func testFailureMessageNamesCasePositionAndAbbreviatesTheInstance() {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.compactDescription.contains("edge case [")
                && issue.compactDescription.contains("negative width")
                && issue.compactDescription.count < 400
        }
        XCTExpectFailure("failure messages carry position and abbreviated instance", options: options) {
            XCTAssertNoThrow(forEach: [Fragment(text: "x", width: -2)]) { fragment in
                try render(fragment)
            }
        }
    }

    func testCustomMessagePrefixesTheFailure() {
        let options = XCTExpectedFailure.Options()
        options.issueMatcher = { issue in
            issue.compactDescription.contains("renderer must survive — edge case [0]")
        }
        XCTExpectFailure("the caller's message leads the failure text", options: options) {
            XCTAssertNoThrow(forEach: [Fragment(text: "x", width: -2)], "renderer must survive") { fragment in
                try render(fragment)
            }
        }
    }
    #endif
}
