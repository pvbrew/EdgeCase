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

## Built-in generators (v0.2)

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
| any `EdgeCaseGeneratable` type | its own `edgeCases`, recursed into |

## Nested types and enums (v0.2)

Annotated types conform to `EdgeCaseGeneratable`, so they compose — and enums get every case with their associated values varied:

```swift
@EdgeCases
struct Order {
    let id: Int
    let coupon: String?        // nil + every String edge case
    let items: [LineItem]      // empty, single, 1,000, LineItem.edgeCases
    let status: Status         // every case, payloads varied
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

Types the macro has no generator for (`Date`, `URL`, …) join in with a manual conformance:

```swift
extension Date: EdgeCaseGeneratable {
    public static var edgeCases: [Date] {
        [.distantPast, .distantFuture, Date(timeIntervalSince1970: 0)]
    }
}
```

### How instances are combined

One property varies at a time while the others hold a baseline value (`0`, `""`, `false`, `nil`, `[]`, or the nested type's `edgeCaseBaseline`), and exact duplicates are removed. The case count grows linearly with the number of properties — the sum of each property's edge cases, never a combinatorial explosion — and when a test fails, the odd value out is the property to blame. Edge cases of nested types are only known at runtime, so they are spliced in by mapping over the nested type's `edgeCases`. Configurable strategies (minimal / combinatorial) are planned for v0.3.

### Requirements & limitations (v0.2)

- Swift 6.0+, iOS 17+ / macOS 10.15+
- Structs and enums; every varied stored property or associated value must be a supported type, a type conforming to `EdgeCaseGeneratable`, or a collection/optional of those
- Stored properties need an explicit type annotation; tuple and function types are not supported
- `let` properties with a default value keep their fixed value; `var` properties with a default are still varied
- Recursive types (`struct Node { let next: Node? }`) would recurse infinitely at runtime — don't annotate them
- Per-property overrides and exclusion land in v0.3 (see roadmap)

## Installation

Swift Package Manager only. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pvbrew/EdgeCase.git", from: "0.2.0")
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

An example iOS app is available in [`Examples/EdgeCaseExample`](Examples/EdgeCaseExample). Its SwiftUI screen renders every generated `User` instance — including the 10,000-character username, `NaN` karma, `nil` bio, 1,000-tag array, right-to-left city name, and every `Membership` case — and its unit test target shows the canonical workflow: iterate `User.edgeCases` through the code under test, plus an `@EdgeCases`-annotated fixture declared directly in the test bundle.

## Roadmap

- **v0.3** — Per-property overrides, exclusion, generation strategies
- **v0.4** — XCTest / swift-testing helpers, CI, DocC

## License

MIT — see [LICENSE](LICENSE).
