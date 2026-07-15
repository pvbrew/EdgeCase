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
/// join in. `edgeCaseBaseline` comes from the protocol's default
/// implementation.
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

// MARK: - v0.3: overrides, strategies, Foundation conformances

/// The v0.3 roadmap goal: a real domain model annotated without fighting the
/// macro — a bounded domain override, excluded properties, and Foundation
/// types.
@EdgeCases
struct Booking {
    @EdgeCase(.custom([0, 1, 149, 150]))
    let age: Int
    @EdgeCase(.exclude)
    var channel: String = "web"
    @EdgeCase(.exclude)
    let fingerprint: String
    let id: UUID
    let createdAt: Date
    let site: URL
}

@EdgeCases(strategy: .minimal)
struct MinimalForm {
    let attempts: Int
    let comment: String
    let agreed: Bool
}

/// Exercises the minimal strategy's runtime form (a nested type's edge cases
/// are only known at runtime).
@EdgeCases(strategy: .minimal)
struct MinimalNested {
    let level: Int
    let owner: Owner
}

@EdgeCases(strategy: .combinatorial)
struct ComboPair {
    let attempts: Int8
    let agreed: Bool
}

/// Exercises the combinatorial runtime loop (nested enum payload).
@EdgeCases(strategy: .combinatorial)
struct ComboNested {
    let agreed: Bool
    let plan: Plan
}

/// 11 × 11 × 11 = 1,331 combinations — over the cap, so generation stops at
/// exactly 1,000 instances (and the expansion emits a compile-time warning).
@EdgeCases(strategy: .combinatorial)
struct ComboCapped {
    @EdgeCase(.custom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
    let x: Int
    @EdgeCase(.custom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
    let y: Int
    @EdgeCase(.custom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
    let z: Int
}

final class EdgeCaseOverrideRuntimeTests: XCTestCase {

    func testCustomOverrideBoundsTheDomain() {
        let ages = Set(Booking.edgeCases.map(\.age))
        XCTAssertEqual(ages, [0, 1, 149, 150], "age never leaves the custom domain")
        XCTAssertEqual(Booking.edgeCaseBaseline.age, 0, "the first custom value is the baseline")
    }

    func testExcludedPropertiesNeverVary() {
        XCTAssertTrue(Booking.edgeCases.allSatisfy { $0.channel == "web" }, "default value is kept")
        XCTAssertTrue(Booking.edgeCases.allSatisfy { $0.fingerprint == "" }, "type baseline is held")
    }

    func testFoundationConformancesParticipate() {
        XCTAssertTrue(Booking.edgeCases.contains { $0.createdAt == .distantFuture })
        XCTAssertTrue(Booking.edgeCases.contains { $0.id.uuidString == "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF" })
        XCTAssertTrue(Booking.edgeCases.contains { $0.site.isFileURL })
        XCTAssertEqual(Date.edgeCaseBaseline, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(URL.edgeCaseBaseline, URL(string: "https://example.com")!)
        XCTAssertEqual(
            UUID.edgeCaseBaseline,
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        )
    }
}

// MARK: - v0.4: fixture composition

final class EdgeCaseComposableRuntimeTests: XCTestCase {

    /// The composition contract: every instance keeps the base's values in
    /// all but the one property currently taking an edge case.
    func testVaryingKeepsBaseValuesWhileOnePropertyTakesEdgeCases() {
        let base = Owner(name: "Ada", rating: 4.5)
        let composed = Owner.edgeCases(varying: base)

        XCTAssertTrue(composed.contains { $0.name.count == 10_000 && $0.rating == 4.5 })
        XCTAssertTrue(composed.contains { $0.rating.isNaN && $0.name == "Ada" })
        XCTAssertTrue(
            composed.allSatisfy { $0.name == "Ada" || $0.rating == 4.5 },
            "no instance may vary two properties at once"
        )
    }

    /// Excluded properties keep the fixture's realistic values — including
    /// the excluded-with-default case, where plain generation would have
    /// reapplied the default.
    func testVaryingPassesExcludedAndOverriddenPropertiesThroughFromBase() {
        let base = Booking(
            age: 42,
            channel: "ios",
            fingerprint: "device-7",
            id: UUID(uuidString: "12345678-1234-4234-8234-123456789012")!,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            site: URL(string: "https://example.org/checkout")!
        )
        let composed = Booking.edgeCases(varying: base)

        XCTAssertTrue(composed.allSatisfy { $0.channel == "ios" }, "default 'web' must not be reapplied")
        XCTAssertTrue(composed.allSatisfy { $0.fingerprint == "device-7" })
        XCTAssertEqual(
            Set(composed.map(\.age)), [0, 1, 149, 150, 42],
            "age varies only within its custom domain, or holds the base value"
        )
        XCTAssertTrue(composed.contains { $0.createdAt == .distantFuture && $0.site == base.site })
    }

    /// Nested `EdgeCaseGeneratable` types splice their runtime cases in
    /// while the rest of the instance stays the base.
    func testVaryingSplicesNestedTypeCasesAroundTheBase() {
        let base = Account(
            id: 7,
            nickname: "nick",
            tags: ["a"],
            scores: [1],
            settings: ["dark": true],
            owner: Owner(name: "Ada", rating: 4.5),
            plan: .paid(renewals: 3)
        )
        let composed = Account.edgeCases(varying: base)

        XCTAssertTrue(composed.contains { $0.owner.rating.isNaN && $0.id == 7 && $0.plan == .paid(renewals: 3) })
        XCTAssertTrue(composed.contains { $0.plan == .paid(renewals: .max) && $0.owner == base.owner })
        XCTAssertTrue(composed.contains { $0.nickname == nil && $0.tags == ["a"] })
    }

    /// Composition is one-property-at-a-time whatever the declared strategy:
    /// the count is the sum of the columns, never their max or product.
    func testVaryingIsOneAtATimeEvenUnderOtherStrategies() {
        let minimal = MinimalForm(attempts: 9, comment: "fine", agreed: true)
        XCTAssertEqual(MinimalForm.edgeCases(varying: minimal).count, 4 + 8 + 2)

        let combo = ComboPair(attempts: 9, agreed: true)
        XCTAssertEqual(ComboPair.edgeCases(varying: combo).count, 4 + 2)
    }

    /// The conformance is usable generically — the composition entry point
    /// for helpers that accept any composable type.
    func testComposableConformanceSupportsGenericCode() {
        func adversaries<T: EdgeCaseComposable>(around base: T) -> Int {
            T.edgeCases(varying: base).count
        }
        // The sum of the property columns: String's 8 cases + Double's 5.
        // (Plain `edgeCases` counts 12: its all-baseline instance is
        // generated once per property and deduplicated; composed instances
        // read distinct values from `base`, so nothing collides.)
        XCTAssertEqual(adversaries(around: Owner(name: "Ada", rating: 4.5)), 8 + 5)
    }
}

// MARK: - v0.4: descriptions

final class EdgeCaseDescriptionTests: XCTestCase {

    func testLongDescriptionsAreElided() {
        let description = edgeCaseDescription(of: String(repeating: "a", count: 10_000))
        XCTAssertEqual(description.count, 80)
        XCTAssertTrue(description.hasSuffix("…"))
    }

    func testShortDescriptionsAreUntouched() {
        XCTAssertEqual(edgeCaseDescription(of: 42), "42")
        XCTAssertEqual(edgeCaseDescription(of: Owner(name: "Ada", rating: 0)), #"Owner(name: "Ada", rating: 0.0)"#)
    }

    func testNewlinesCollapseToSpaces() {
        XCTAssertEqual(edgeCaseDescription(of: "a\nb\r\nc"), "a b c")
    }

    func testCustomMaximumLength() {
        XCTAssertEqual(edgeCaseDescription(of: "abcdef", maxLength: 4), "abc…")
        XCTAssertEqual(edgeCaseDescription(of: "abcd", maxLength: 4), "abcd")
    }
}

final class EdgeCaseStrategyRuntimeTests: XCTestCase {

    func testMinimalCountIsTheLargestColumn() {
        // String has the most edge cases (8); Int (4) and Bool (2) cycle.
        XCTAssertEqual(MinimalForm.edgeCases.count, 8)
        XCTAssertEqual(Set(MinimalForm.edgeCases.map(\.attempts)), [Int.min, Int.max, 0, -1])
        XCTAssertTrue(MinimalForm.edgeCases.contains { $0.comment.count == 10_000 })
        XCTAssertTrue(MinimalForm.edgeCases.allSatisfy { $0.attempts != 0 || $0.comment != "" || $0.agreed },
                      "minimal has no all-baseline instance; every property carries an edge value")
    }

    func testMinimalRuntimeFormCyclesThroughNestedCases() {
        XCTAssertEqual(MinimalNested.edgeCases.count, max(4, Owner.edgeCases.count))
        XCTAssertEqual(Set(MinimalNested.edgeCases.map(\.level)), [Int.min, Int.max, 0, -1])
        XCTAssertTrue(MinimalNested.edgeCases.contains { $0.owner.name.count == 10_000 })
    }

    func testCombinatorialCoversTheFullProduct() {
        XCTAssertEqual(ComboPair.edgeCases.count, 4 * 2)
        // Pairings one-at-a-time never produces.
        XCTAssertTrue(ComboPair.edgeCases.contains { $0.attempts == .max && $0.agreed })
        XCTAssertTrue(ComboPair.edgeCases.contains { $0.attempts == .min && $0.agreed })
    }

    func testCombinatorialRuntimeLoopCrossesNestedCases() {
        XCTAssertEqual(ComboNested.edgeCases.count, 2 * Plan.edgeCases.count)
        XCTAssertTrue(ComboNested.edgeCases.contains { $0.agreed && $0.plan == .paid(renewals: .max) })
    }

    func testCombinatorialGenerationIsCapped() {
        XCTAssertEqual(ComboCapped.edgeCases.count, 1_000, "1,331 combinations are capped at 1,000")
    }
}
