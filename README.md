# EdgeCase

You test the happy path. `@EdgeCases` generates the ones you forgot — the empty string, the `Int.max`, the `NaN` — in one line.

EdgeCase is a Swift macro that inspects the stored properties of a struct and generates a `static var edgeCases: [Self]` full of boundary and adversarial values, ready to feed into your tests.

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

@EdgeCases
struct User {
    let id: Int
    let name: String
    var isActive: Bool
}

func testProfileRendering() {
    for user in User.edgeCases {
        XCTAssertNoThrow(try render(user))
    }
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

…plus a `static var edgeCaseBaseline: Self` and an `EdgeCaseGeneratable` conformance, so annotated types can nest inside each other.

## Built-in generators (v0.3)

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

## Per-property overrides (v0.3)

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

## Generation strategies (v0.3)

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

### Requirements & limitations (v0.3)

- Swift 6.0+, iOS 17+ / macOS 10.15+
- Structs and enums; every varied stored property or associated value must be a supported type, a type conforming to `EdgeCaseGeneratable`, or a collection/optional of those — or carry an `@EdgeCase(.custom([...]))` override
- Stored properties need an explicit type annotation (except under `.custom`)
- `let` properties with a default value keep their fixed value; `var` properties with a default are still varied
- `@EdgeCase` overrides work on struct properties, not on enum associated values
- Recursive types (`struct Node { let next: Node? }`) would recurse infinitely at runtime — don't annotate them
- A custom `EdgeCaseGeneratable` conformance must return a non-empty `edgeCases`

## Installation

Swift Package Manager only. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pvbrew/EdgeCase.git", from: "0.3.0")
]
```

and add the product to your test target:

```swift
.testTarget(
    name: "MyAppTests",
    dependencies: [
        .product(name: "EdgeCase", package: "EdgeCase")
    ]
)
```

Or in Xcode: **File ▸ Add Package Dependencies…** and paste the repo URL.

## Example

An example iOS app is available in [`Examples/EdgeCaseExample`](Examples/EdgeCaseExample). Its SwiftUI screen renders every generated `User` instance — including the 10,000-character username, `NaN` karma, `nil` bio, 1,000-tag array, right-to-left city name, `.distantPast` join date, and `file://` website — with `age` bounded to its real domain by `@EdgeCase(.custom([...]))` and a cosmetic property pinned by `@EdgeCase(.exclude)`. Its unit test target shows the canonical workflow plus `.minimal` and `.combinatorial` fixtures declared directly in the test bundle.

## Roadmap

- **v0.4** — XCTest / swift-testing helpers, CI, DocC
- **v1.0** — API freeze, full documentation

## License

MIT — see [LICENSE](LICENSE).
