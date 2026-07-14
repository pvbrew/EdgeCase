import EdgeCase
import XCTest

// The realistic model from the v0.2 roadmap goal: optional fields, arrays,
// dictionaries, sets, a nested custom type, and an enum — all recursed into
// from one annotation. These tests compile and run the generated code, which
// the expansion tests in EdgeCaseTests cannot do.

@EdgeCases
struct Account {
    let id: Int
    let nickname: String?
    let tags: [String]
    let scores: Set<Int>
    let settings: [String: Bool]
    let owner: Owner
    let plan: Plan
}

@EdgeCases
struct Owner: Equatable {
    let name: String
    let rating: Double
}

@EdgeCases
enum Plan: Equatable {
    case free
    case paid(renewals: Int)
}

/// Exercises distinct-value synthesis for every key/element kind that can
/// provide it: `Set(0 ..< 1_000)`, `map(Int16.init)`, `map(Double.init)`,
/// Int-keyed `zip`, and the capped `Int8` range.
@EdgeCases
struct Grid {
    let widths: Set<Int16>
    let weights: Set<Double>
    let limits: [Int: Double]
    let bytes: Set<Int8>
}

final class EdgeCaseRuntimeTests: XCTestCase {

    // MARK: Enums

    func testEnumGeneratesEveryCaseAndVariesPayloads() {
        XCTAssertEqual(
            Plan.edgeCases,
            [.free, .paid(renewals: .min), .paid(renewals: .max), .paid(renewals: 0), .paid(renewals: -1)]
        )
        XCTAssertEqual(Plan.edgeCaseBaseline, .free)
    }

    // MARK: Nested types

    func testNestedTypeEdgeCasesAreRecursedInto() {
        XCTAssertTrue(Account.edgeCases.contains { $0.owner.rating.isNaN })
        XCTAssertTrue(Account.edgeCases.contains { $0.owner.name.count == 10_000 })
        XCTAssertTrue(Account.edgeCases.contains { $0.plan == .paid(renewals: .max) })
        XCTAssertEqual(Owner.edgeCaseBaseline, Owner(name: "", rating: 0))
    }

    // MARK: Optionals

    func testOptionalCoversNilAndWrappedEdgeCases() {
        XCTAssertTrue(Account.edgeCases.contains { $0.nickname == nil })
        XCTAssertTrue(Account.edgeCases.contains { $0.nickname == "" })
        XCTAssertTrue(Account.edgeCases.contains { $0.nickname?.count == 10_000 })
    }

    // MARK: Collections

    func testArrayCoversEmptySingleLargeAndAllEdgeCaseElements() {
        XCTAssertTrue(Account.edgeCases.contains { $0.tags.isEmpty })
        XCTAssertTrue(Account.edgeCases.contains { $0.tags.count == 1 })
        XCTAssertTrue(Account.edgeCases.contains { $0.tags.count == 1_000 })
        XCTAssertTrue(
            Account.edgeCases.contains { account in
                account.tags.contains { $0.count == 10_000 }
            },
            "one generated array should hold every String edge case as elements"
        )
    }

    func testSetAndDictionaryCoverEmptyAndLarge() {
        XCTAssertTrue(Account.edgeCases.contains { $0.scores.isEmpty })
        XCTAssertTrue(Account.edgeCases.contains { $0.scores.count == 1_000 })
        XCTAssertTrue(Account.edgeCases.contains { $0.settings.isEmpty })
        XCTAssertTrue(Account.edgeCases.contains { $0.settings.count == 1_000 })
    }

    func testDistinctValueSynthesisAcrossKeyAndElementTypes() {
        XCTAssertTrue(Grid.edgeCases.contains { $0.widths.count == 1_000 })
        XCTAssertTrue(Grid.edgeCases.contains { $0.weights.count == 1_000 })
        XCTAssertTrue(Grid.edgeCases.contains { $0.limits.count == 1_000 })
        XCTAssertTrue(Grid.edgeCases.contains { $0.bytes.count == 100 }, "Int8 cannot represent 1_000 distinct values")
    }

    // MARK: Strings

    func testStringCoversUnicodeAdversaries() {
        let nicknames = Account.edgeCases.compactMap(\.nickname)
        XCTAssertTrue(nicknames.contains { $0.unicodeScalars.contains("\u{200D}") }, "emoji ZWJ sequence")
        XCTAssertTrue(nicknames.contains { $0.contains("\u{0645}") }, "right-to-left text")
        XCTAssertTrue(nicknames.contains { $0.unicodeScalars.contains("\u{200B}") }, "zero-width space")
        XCTAssertTrue(
            nicknames.contains { $0.count != $0.unicodeScalars.count && $0.contains("Cafe\u{0301}") },
            "combining diacritics"
        )
    }

    // MARK: Baseline & shape

    func testBaselineIsAllNeutralValues() {
        let baseline = Account.edgeCaseBaseline
        XCTAssertEqual(baseline.id, 0)
        XCTAssertNil(baseline.nickname)
        XCTAssertTrue(baseline.tags.isEmpty)
        XCTAssertTrue(baseline.scores.isEmpty)
        XCTAssertTrue(baseline.settings.isEmpty)
        XCTAssertEqual(baseline.owner, Owner(name: "", rating: 0))
        XCTAssertEqual(baseline.plan, .free)
    }

    func testCaseCountGrowsLinearlyNotCombinatorially() {
        // One varied value per instance: the total is roughly the sum of each
        // property's edge cases, never their product.
        XCTAssertGreaterThan(Account.edgeCases.count, 20)
        XCTAssertLessThan(Account.edgeCases.count, 60)
    }

    // MARK: Manual conformances

    func testManualConformanceParticipatesInGeneration() {
        XCTAssertEqual(Stamped.edgeCases.count, Timestamp.edgeCases.count)
        XCTAssertEqual(Stamped.edgeCaseBaseline.at, .distantPast, "default baseline is the first edge case")
    }
}

/// A hand-written conformance — how types the macro has no generator for
/// (`Date`, `URL`, ...) join in. `edgeCaseBaseline` comes from the protocol's
/// default implementation.
struct Timestamp: Equatable, EdgeCaseGeneratable {
    static let distantPast = Timestamp(secondsSince1970: -62_135_596_800)
    static let distantFuture = Timestamp(secondsSince1970: 64_092_211_200)

    let secondsSince1970: Int64

    static var edgeCases: [Timestamp] {
        [distantPast, distantFuture, Timestamp(secondsSince1970: 0)]
    }
}

@EdgeCases
struct Stamped {
    let at: Timestamp
}
