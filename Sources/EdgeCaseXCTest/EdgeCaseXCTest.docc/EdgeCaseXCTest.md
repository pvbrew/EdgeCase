# ``EdgeCaseXCTest``

One-line XCTest assertions that run a body over every generated edge case and
report each failing instance.

## Overview

`XCTAssertNoThrow(forEachEdgeCase:)` runs its body once per generated instance
of a type. Unlike the standard `XCTAssertNoThrow`, it keeps iterating past
failures, recording one test failure per throwing case — a single run reports
every offending instance, each named by its position and an abbreviated
description:

```swift
import EdgeCaseXCTest

func testProfileRendering() {
    XCTAssertNoThrow(forEachEdgeCase: User.self) { user in
        try render(user)
    }
}
```

The `forEach:` overload takes an explicit sequence instead of a type — use it
with composed or hand-picked case lists:

```swift
XCTAssertNoThrow(forEach: User.edgeCases(varying: .fixture())) { user in
    try render(user)
}
```

This module links XCTest — add the `EdgeCaseXCTest` product to test targets
only.

## Topics

### Asserting over edge cases

- ``XCTAssertNoThrow(forEachEdgeCase:_:file:line:_:)``
- ``XCTAssertNoThrow(forEach:_:file:line:_:)``
