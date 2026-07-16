# ``EdgeCaseTesting``

Readable labels for feeding generated edge cases to swift-testing's
parameterized tests.

## Overview

`edgeCases` is a plain `[Self]`, so it feeds `@Test(arguments:)` without this
module — but swift-testing labels each argument with its full description, and
EdgeCase generates 10,000-character strings and 1,000-element collections on
purpose. `EdgeCaseTesting` wraps each instance in a ``LabeledEdgeCase`` with a
short, indexed label instead:

```swift
import EdgeCaseTesting
import Testing

@Test(arguments: User.labeledEdgeCases)
func profileRendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)   // shown as "[3] User(id: 92233…" in the navigator
}
```

Composed cases get the same treatment: `labeledEdgeCases(varying:)` labels the
instances of `edgeCases(varying:)`, pairing a realistic fixture with one
adversarial property at a time:

```swift
@Test(arguments: User.labeledEdgeCases(varying: .fixture()))
func profileRendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)
}
```

This module links the Testing framework — add the `EdgeCaseTesting` product to
test targets only.

## Topics

### Labeling edge cases

- ``LabeledEdgeCase``
- ``EdgeCase/EdgeCaseGeneratable/labeledEdgeCases``
- ``EdgeCase/EdgeCaseComposable/labeledEdgeCases(varying:)``
