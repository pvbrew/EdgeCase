# Getting Started

Annotate a model, get its adversarial instances, and shape generation to
your domain.

## Overview

Add the package to your test target — EdgeCase is SPM-only:

```swift
dependencies: [
    .package(url: "https://github.com/pvbrew/EdgeCase.git", from: "1.0.0")
],
targets: [
    .testTarget(
        name: "MyAppTests",
        dependencies: [
            .product(name: "EdgeCase", package: "EdgeCase")
        ]
    )
]
```

### Annotate a type

Attach ``EdgeCases(strategy:)`` to a struct or an enum whose stored
properties (or associated values) are supported types:

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

`Order.edgeCases` now covers every property's boundary values —
`Int.min`/`Int.max`, empty and 10,000-character strings, unicode
adversaries (emoji, right-to-left text, zero-width characters, combining
diacritics), `nil`, empty and 1,000-element collections, `.distantPast`, and
more. Under the default strategy one property varies at a time, so a failing
instance points directly at the property to blame.

### Bound properties to their real domain

Real domain models have real domains. The ``EdgeCase(_:)`` marker overrides
one property without giving up generation for the rest:

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

### Pick a strategy

``EdgeCaseStrategy`` controls how property edge cases combine into
instances:

```swift
@EdgeCases                              // .oneAtATime — the default
@EdgeCases(strategy: .minimal)          // fewest instances, full value coverage
@EdgeCases(strategy: .combinatorial)    // cartesian product, capped at 1,000
```

### Bring your own types

Types the macro has no generator for join in through a manual
``EdgeCaseGeneratable`` conformance (`Date`, `URL`, and `UUID` ship with the
library):

```swift
extension Decimal: EdgeCaseGeneratable {
    public static var edgeCases: [Decimal] {
        [0, .greatestFiniteMagnitude, .leastFiniteMagnitude]
    }
}
```

The macro fails loudly instead of generating something surprising:
unsupported property types without a default value are compile-time errors,
and warnings point at the fix when a property is skipped, an override can
have no effect, or `.combinatorial` blows past its cap.

Next, feed the generated cases into your test suite: <doc:TestingIntegration>.
