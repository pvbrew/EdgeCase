# Testing Integration

Plug generated edge cases into swift-testing or XCTest, and compose them
with your fixtures.

## Overview

EdgeCase ships two companion products so the integration is one line in
either framework. Both link a testing framework, so add them to test targets
only:

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

`edgeCases` is a plain `[Self]`, so it feeds `@Test(arguments:)` directly:

```swift
import Testing

@Test(arguments: User.edgeCases)
func profileRendering(user: User) throws {
    try render(user)
}
```

That works without any EdgeCase addition — but the test navigator labels
each argument with its full description, and EdgeCase generates
10,000-character strings on purpose. `EdgeCaseTesting`'s `labeledEdgeCases`
wraps each instance in a `LabeledEdgeCase` with a short, indexed label:

```swift
import EdgeCaseTesting

@Test(arguments: User.labeledEdgeCases)
func profileRendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)   // labeled "[3] User(id: 9223372036854…"
}
```

### XCTest

`EdgeCaseXCTest` adds the `forEachEdgeCase:` overload of `XCTAssertNoThrow`.
It runs the body once per generated instance and — unlike its standard
sibling — keeps iterating past failures, reporting every offending instance
with its position and an abbreviated description:

```swift
import EdgeCaseXCTest

func testProfileRendering() {
    XCTAssertNoThrow(forEachEdgeCase: User.self) { user in
        try render(user)
    }
}
```

An overload taking an explicit sequence covers composed or hand-picked case
lists: `XCTAssertNoThrow(forEach: someCases) { ... }`.

### Composing with fixtures

Generated edge cases are all-neutral except the varied property — realistic
apps deserve realistic surroundings. If you use a fixtures-style library (or
any hand-rolled `.fixture()` factory), ``EdgeCaseComposable`` composes the
two: `edgeCases(varying:)` keeps the base instance's values while one
property at a time takes its edge cases:

```swift
let user = User.fixture()   // realistic: name "Ada", 34 followers, …

@Test(arguments: User.edgeCases(varying: user))
func profileRendering(user: User) throws {
    try render(user)        // realistic user, one adversarial field
}
```

Excluded properties keep the fixture's values rather than reapplying their
defaults, and composition is always one-property-at-a-time regardless of the
declared strategy — holding everything else at the fixture is the point.
`@EdgeCases` generates the conformance for structs; enums don't get one,
because a base enum value is a single case and its adversaries are simply
the other cases in `edgeCases`.

Composition and labels combine: `labeledEdgeCases(varying:)` from
`EdgeCaseTesting` wraps each composed instance the same way
`labeledEdgeCases` wraps the plain list:

```swift
@Test(arguments: User.labeledEdgeCases(varying: .fixture()))
func profileRendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)
}
```

### Readable failure output

All the helpers abbreviate instance descriptions with
``edgeCaseDescription(of:maxLength:)`` — use it in your own assertions to
keep 10,000-character strings out of your logs:

```swift
XCTAssertTrue(isValid(user), "unexpected: \(edgeCaseDescription(of: user))")
```
