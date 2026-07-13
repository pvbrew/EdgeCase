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
        Self(id: 0, name: "", isActive: true),
    ]
}
```

## Built-in generators (v0.1)

| Type | Edge cases |
| --- | --- |
| `Int`, `Int8`, `Int16`, `Int32`, `Int64` | `.min`, `.max`, `0`, `-1` |
| `Double`, `Float` | `-.greatestFiniteMagnitude`, `.greatestFiniteMagnitude`, `0`, `.nan`, `.infinity` |
| `String` | empty, single character, 10,000 characters, whitespace-only |
| `Bool` | `true`, `false` |

### How instances are combined

One property varies at a time while the others hold a baseline value (`0`, `""`, `false`), and exact duplicates are removed. The case count grows linearly with the number of properties — the sum of each property's edge cases, never a combinatorial explosion — and when a test fails, the odd value out is the property to blame. Configurable strategies (minimal / combinatorial) are planned for v0.3.

### Requirements & limitations (v0.1)

- Swift 6.0+, iOS 17+ / macOS 10.15+
- Structs only; every varied stored property must be one of the supported types above and have an explicit type annotation
- `let` properties with a default value keep their fixed value; `var` properties with a default are still varied
- Optionals, collections, nested types, and enums land in v0.2+ (see roadmap)

## Installation

Swift Package Manager only. In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/pvbrew/EdgeCase.git", from: "0.1.0")
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

An example iOS app is available in [`Examples/EdgeCaseExample`](Examples/EdgeCaseExample). Its SwiftUI screen renders every generated `User` instance — including the 10,000-character username and `NaN` karma — and its unit test target shows the canonical workflow: iterate `User.edgeCases` through the code under test, plus an `@EdgeCases`-annotated fixture declared directly in the test bundle.

## Roadmap

- **v0.2** — Optionals, collections (`Array`, `Dictionary`, `Set`), unicode string cases, nested types, enums
- **v0.3** — Per-property overrides, exclusion, generation strategies, custom generator protocol
- **v0.4** — XCTest / swift-testing helpers, CI, DocC

## License

MIT — see [LICENSE](LICENSE).
