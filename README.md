# EdgeCase

[![CI](https://github.com/pvbrew/EdgeCase/actions/workflows/ci.yml/badge.svg)](https://github.com/pvbrew/EdgeCase/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-DocC-blue)](https://pvbrew.github.io/EdgeCase/)
[![License: MIT](https://img.shields.io/badge/license-MIT-lightgrey)](LICENSE)

You test the happy path. `@EdgeCases` generates the ones you forgot — the empty string, the `Int.max`, the `NaN` — in one line.

EdgeCase is a Swift macro that inspects the stored properties of a struct (or the cases of an enum) and generates a `static var edgeCases: [Self]` full of boundary and adversarial values, ready to feed into your tests.

## Before

```swift
func testProfileRendering() {
    let cases = [
        User(id: 1, name: "Ada", isActive: true),   // the case you wrote
        User(id: 0, name: "", isActive: false),     // the ones you
        User(id: .max, name: "", isActive: false),  // remembered
        // ...and the ones you forgot
    ]
    for user in cases {
        XCTAssertNoThrow(try render(user))
    }
}
```

## After

```swift
import EdgeCase
import Testing

@EdgeCases
struct User {
    let id: Int
    let name: String
    var isActive: Bool
}

@Test(arguments: User.edgeCases)
func profileRendering(user: User) throws {
    try render(user)
}
```

The macro expands to:

```swift
static var edgeCases: [Self] {
    [
        Self(id: Int.min, name: "", isActive: false),
        Self(id: Int.max, name: "", isActive: false),
        Self(id: 0, name: "", isActive: false),
        Self(id: -1, name: "", isActive: false),
        Self(id: 0, name: "a", isActive: false),
        Self(id: 0, name: String(repeating: "a", count: 10_000), isActive: false),
        Self(id: 0, name: " \t\n", isActive: false),
        Self(id: 0, name: "\u{1F9D1}\u{200D}\u{1F680}\u{1F44D}\u{1F3FD}\u{1F1EC}\u{1F1F7}", isActive: false),
        Self(id: 0, name: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{05E9}\u{05DC}\u{05D5}\u{05DD}", isActive: false),
        Self(id: 0, name: "a\u{200B}b\u{200C}c\u{200D}d", isActive: false),
        Self(id: 0, name: "Cafe\u{0301}", isActive: false),
        Self(id: 0, name: "", isActive: true),
    ]
}
```

…plus a `static var edgeCaseBaseline: Self`, an `EdgeCaseGeneratable` conformance so annotated types can nest inside each other, and — for structs — a `static func edgeCases(varying:)` that composes edge cases around a realistic fixture (see [Composing with fixtures](#composing-with-fixtures)).

## Built-in generators

| Type | Edge cases |
| --- | --- |
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | `.min`, `.max`, `0`, `-1` |
| `Double`, `Float` | `-.greatestFiniteMagnitude`, `.greatestFiniteMagnitude`, `0`, `.nan`, `.infinity` |
| `String` | empty, single character, 10,000 characters, whitespace-only, emoji (ZWJ sequence, skin tone, flag), right-to-left text (Arabic/Hebrew), zero-width characters, combining diacritics |
| `Bool` | `true`, `false` |
| `Optional<T>` | `nil`, plus every edge case of `T` |
| `Array<T>` | empty, single element, 1,000 elements, all edge cases of `T` as elements |
| `Set<T>` | empty, 1,000 distinct elements |
| `Dictionary<K, V>` | empty, 1,000 entries |
| `Date` | epoch, one second before it, `.distantPast`, `.distantFuture`, past the Y2038 32-bit rollover |
| `URL` | plain, scheme-less single character, port/escapes/duplicate query keys/fragment, punycode host + percent-encoded emoji path, 2,000-character path, `file://` |
| `UUID` | nil UUID (all zeros), all ones, minimal v4-shaped |
| any `EdgeCaseGeneratable` type | its own `edgeCases`, recursed into |

`Date`, `URL`, and `UUID` participate through `EdgeCaseGeneratable` conformances that ship with the library — if you wrote your own in v0.2, delete them when upgrading.

## Per-property overrides

Real domain models have real domains. `@EdgeCase` overrides one property without giving up generation for the rest:

```swift
@EdgeCases
struct Patient {
    @EdgeCase(.custom([0, 1, 149, 150]))
    let age: Int                        // your boundaries, not Int.min/.max

    @EdgeCase(.exclude)
    var avatar: String = "person"      // held at its default, never varied

    let notes: String                   // generated as usual
}
```

- `.custom([...])` replaces the generated cases with your list (written as an array literal — the expressions are spliced in at compile time, and the first value doubles as the property's baseline). It also works on types the macro has no generator for, like tuples.
- `.exclude` pins the property: to its default value if it has one, otherwise to its type's baseline (`0`, `""`, `nil`, `[]`, …).

Overrides apply to stored instance properties of structs; the macro warns when one can have no effect (computed, `static`, `lazy`, or `let` with a fixed value).

## Generation strategies

`@EdgeCases(strategy:)` picks how property edge cases combine into instances:

```swift
@EdgeCases                              // .oneAtATime is the default
@EdgeCases(strategy: .minimal)
@EdgeCases(strategy: .combinatorial)
```

| Strategy | Instances for `(Int, String, Bool)` | What it's for |
| --- | --- | --- |
| `.oneAtATime` | 4 + 8 + 2 − duplicates ≈ 12 | One property varies while the rest hold a baseline. A failure points straight at the culprit. The default. |
| `.minimal` | max(4, 8, 2) = 8 | Instance *i* takes the *i*-th edge case of *every* property (shorter lists cycle). The smallest set that still uses every edge value — a cheap smoke-test suite. |
| `.combinatorial` | 4 × 8 × 2 = 64 | The full cartesian product, for cross-field validation bugs that only appear when two adversarial values meet. Capped at 1,000 instances, with a compile-time warning when the cap is exceeded. |

## Drop into your test suite

Two companion products plug the generated cases into either test framework. Both link a testing framework, so add them to test targets only:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        .product(name: "EdgeCase", package: "EdgeCase"),
        .product(name: "EdgeCaseTesting", package: "EdgeCase"),  // swift-testing
        .product(name: "EdgeCaseXCTest", package: "EdgeCase"),   // XCTest
    ]
)
```

### swift-testing

`edgeCases` is a plain `[Self]`, so it feeds `@Test(arguments:)` directly — one test *case* per instance, and a failure names the exact adversarial value. For readable output, `EdgeCaseTesting`'s `labeledEdgeCases` wraps each instance with a short indexed label instead of a 10,000-character description:

```swift
import EdgeCaseTesting

@Test(arguments: User.labeledEdgeCases)
func profileRendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)   // shown as "[3] User(id: 92233…" in the navigator
}
```

### XCTest

`EdgeCaseXCTest` adds a `forEachEdgeCase:` overload of `XCTAssertNoThrow` — and unlike the standard one, it keeps iterating past failures, reporting every offending instance with its position and an abbreviated description:

```swift
import EdgeCaseXCTest

func testProfileRendering() {
    XCTAssertNoThrow(forEachEdgeCase: User.self) { user in
        try render(user)
    }
}
```

An overload takes explicit case lists: `XCTAssertNoThrow(forEach: cases) { ... }`.

## Composing with fixtures

Generated edge cases are all-neutral except the varied property. If you build realistic instances with a fixtures-style library (or a hand-rolled `.fixture()` factory), the generated `EdgeCaseComposable` conformance composes the two — `edgeCases(varying:)` keeps the base's values while one property at a time takes its edge cases:

```swift
let user = User.fixture()   // realistic: name "Ada", 34 followers, …

@Test(arguments: User.edgeCases(varying: user))
func profileRendering(user: User) throws {
    try render(user)        // realistic user, one adversarial field
}
```

Excluded properties keep the fixture's values instead of reapplying their defaults, and composition is always one-property-at-a-time regardless of the declared strategy — holding everything else at the fixture is the point. Structs get the conformance; enums don't (a base enum value is a single case, and its adversaries are simply the other cases).

Composition and labels combine — `labeledEdgeCases(varying:)` from `EdgeCaseTesting` gives composed cases the same short navigator labels:

```swift
@Test(arguments: User.labeledEdgeCases(varying: .fixture()))
func profileRendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)
}
```

## Nested types and enums

Annotated types conform to `EdgeCaseGeneratable`, so they compose — and enums get every case with their associated values varied:

```swift
@EdgeCases
struct Order {
    let id: Int
    let coupon: String?        // nil + every String edge case
    let items: [LineItem]      // empty, single, 1,000, LineItem.edgeCases
    let status: Status         // every case, payloads varied
    let placedAt: Date         // bundled Foundation conformance
}

@EdgeCases
struct LineItem {
    let sku: String
    let quantity: Int
}

@EdgeCases
enum Status {
    case pending
    case shipped(trackingID: Int)
}
```

Types the macro has no generator for join in with a manual conformance:

```swift
extension Decimal: EdgeCaseGeneratable {
    public static var edgeCases: [Decimal] {
        [0, .greatestFiniteMagnitude, .leastFiniteMagnitude]
    }
}
```

### How instances are combined

Under the default `.oneAtATime` strategy, one property varies at a time while the others hold a baseline value (`0`, `""`, `false`, `nil`, `[]`, or the nested type's `edgeCaseBaseline`), and exact duplicates are removed. The case count grows linearly with the number of properties — and when a test fails, the odd value out is the property to blame. Edge cases of nested types are only known at runtime, so they are spliced in by mapping over the nested type's `edgeCases`; the non-default strategies emit a small runtime loop for the same reason.

### Diagnostics

The macro fails loudly instead of generating something surprising: unsupported property types without a default value are compile-time errors, and it warns — pointing at the fix — when a property type has no generator but a default value to fall back on, when an override can have no effect, and when `.combinatorial` blows past the 1,000-instance cap.

### Requirements & limitations

- Swift 6.0+, iOS 17+ / macOS 10.15+
- Structs and enums; every varied stored property or associated value must be a supported type, a type conforming to `EdgeCaseGeneratable`, or a collection/optional of those — or carry an `@EdgeCase(.custom([...]))` override
- Stored properties need an explicit type annotation (except under `.custom`)
- `let` properties with a default value keep their fixed value; `var` properties with a default are still varied
- `@EdgeCase` overrides work on struct properties, not on enum associated values
- Recursive types (`struct Node { let next: Node? }`) would recurse infinitely at runtime — don't annotate them
- A custom `EdgeCaseGeneratable` conformance must return a non-empty `edgeCases`
- In modules with main-actor default isolation (Xcode's "Approachable Concurrency" app templates), declare the annotated type `nonisolated` — the generated conformances mirror the modifier, keeping `edgeCases` callable from nonisolated test code

## Installation

Swift Package Manager only. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pvbrew/EdgeCase.git", from: "1.0.0")
]
```

and add the products to your test target — `EdgeCase` for the macro, plus the [integration companion](#drop-into-your-test-suite) for your test framework:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        .product(name: "EdgeCase", package: "EdgeCase"),
        .product(name: "EdgeCaseTesting", package: "EdgeCase"),  // swift-testing helpers
        .product(name: "EdgeCaseXCTest", package: "EdgeCase"),   // XCTest helpers
    ]
)
```

Or in Xcode: **File ▸ Add Package Dependencies…** and paste the repo URL.

## Example

An example iOS app is available in [`Examples/EdgeCaseExample`](Examples/EdgeCaseExample). Its SwiftUI screen renders every generated `User` instance — including the 10,000-character username, `NaN` karma, `nil` bio, 1,000-tag array, right-to-left city name, `.distantPast` join date, and `file://` website — with `age` bounded to its real domain by `@EdgeCase(.custom([...]))` and a cosmetic property pinned by `@EdgeCase(.exclude)`. Its test target shows both integrations side by side: a swift-testing suite driving `@Test(arguments:)` with labeled edge cases and fixture composition, and an XCTest suite using `XCTAssertNoThrow(forEachEdgeCase:)` next to the canonical loop-based workflow.

## Documentation

Hosted documentation for all three modules lives at **[pvbrew.github.io/EdgeCase](https://pvbrew.github.io/EdgeCase/)** — start with [Getting Started](https://pvbrew.github.io/EdgeCase/documentation/edgecase/gettingstarted) and [Testing Integration](https://pvbrew.github.io/EdgeCase/documentation/edgecase/testingintegration). The DocC catalogs also ship with the package: open the EdgeCase scheme in Xcode and run **Product ▸ Build Documentation**, or read the articles as markdown in [`Sources/EdgeCase/EdgeCase.docc`](Sources/EdgeCase/EdgeCase.docc).

## Versioning

EdgeCase follows [Semantic Versioning](https://semver.org) from 1.0.0 onward: the macro signatures, the `EdgeCaseGeneratable`/`EdgeCaseComposable` protocols, and the companion APIs only break in major versions, and CI diffs the public API against the latest release on every pull request. The concrete generated *values* are a quality surface, not an API — minor releases may add or refine edge cases (changing case counts), so write tests against behaviors (`contains { $0.karma.isNaN }`), not exact indices or counts. The full policy: [API_STABILITY.md](API_STABILITY.md). Release history: [CHANGELOG.md](CHANGELOG.md).

## Roadmap

**v1.0 (current)** — stable API, full DocC coverage, hosted docs, semver commitment.

Shipped along the way: **v0.1** core macro & primitives · **v0.2** optionals, collections, unicode, nesting, enums · **v0.3** overrides, strategies, Foundation conformances · **v0.4** swift-testing & XCTest integration, fixture composition, CI, DocC

Under consideration (unscheduled): `Codable` round-trip edge cases (malformed JSON inputs), property-based-testing integration, and more built-in Foundation generators. Have a case for one? [Open an issue](https://github.com/pvbrew/EdgeCase/issues).

## License

MIT — see [LICENSE](LICENSE).
