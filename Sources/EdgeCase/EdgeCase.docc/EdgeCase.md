# ``EdgeCase``

Generate the test cases you forgot — boundary and adversarial instances of
your own types, in one line.

## Overview

You test the happy path. `@EdgeCases` generates the ones you forgot — the
empty string, the `Int.max`, the `NaN`, the 10,000-character username — by
inspecting the stored properties of a struct or the cases of an enum and
synthesizing a `static var edgeCases: [Self]` at compile time:

```swift
import EdgeCase

@EdgeCases
struct User {
    let id: Int
    let name: String
    var isActive: Bool
}

// User.edgeCases now holds Int.min/.max ids, empty/huge/right-to-left
// names, both flags — ready to feed a parameterized test.
```

Annotated types also receive a `static var edgeCaseBaseline: Self` (the
all-neutral instance), an ``EdgeCaseGeneratable`` conformance so they can
nest inside each other, and — for structs — an ``EdgeCaseComposable``
conformance whose `edgeCases(varying:)` composes adversarial values around a
realistic fixture.

Start with <doc:GettingStarted>, then wire the generated cases into XCTest
or swift-testing with <doc:TestingIntegration>.

## Topics

### Essentials

- <doc:GettingStarted>
- ``EdgeCases(strategy:)``
- ``EdgeCaseGeneratable``

### Shaping generation

- ``EdgeCase(_:)``
- ``EdgeCaseOverride``
- ``EdgeCaseStrategy``

### Using edge cases in tests

- <doc:TestingIntegration>
- ``EdgeCaseComposable``
- ``edgeCaseDescription(of:maxLength:)``
