# r/swift post

**Suggested title:** I made a macro that generates the test cases you forgot — EdgeCase 1.0

---

You test the happy path. Production crashes on the 10,000-character username,
the `.nan` karma value, the empty tag array, the right-to-left display name.

I got tired of hand-writing those fixtures, so I built **EdgeCase**: a macro
that reads your struct's stored properties and generates the adversarial
instances for you, at compile time:

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

`User.edgeCases` now covers `Int.min`/`.max` ids; empty, single-char, 10,000-
character, whitespace-only, emoji, RTL, zero-width, and combining-diacritic
names; both flags. Optionals add `nil`, arrays add empty/single/1,000-element
cases, nested types and enums recurse.

For real models there are per-property overrides (`@EdgeCase(.custom([0, 13,
118]))` for an `age` with an actual domain), three generation strategies
(one-at-a-time / minimal / full cartesian product with a cap), fixture
composition (`edgeCases(varying: .fixture())` — realistic instance, one
adversarial field at a time), and sugar for both swift-testing and XCTest.

Just tagged **1.0** — API frozen, semver from here (there's an API-breakage
check in CI), docs hosted at https://pvbrew.github.io/EdgeCase/.

Swift 6, SPM-only, MIT: https://github.com/pvbrew/EdgeCase

Would love to hear what edge cases bite you that it doesn't generate yet.
