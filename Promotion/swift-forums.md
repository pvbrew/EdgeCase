# Swift Forums post

**Category:** Related Projects
**Suggested title:** EdgeCase 1.0 — a macro that generates the test cases you forgot

---

Hi all,

I've just tagged 1.0 of **EdgeCase**, a Swift macro that generates boundary
and adversarial test data for your own types, and I'd love feedback from
people who test real production models.

**Repo:** https://github.com/pvbrew/EdgeCase
**Docs:** https://pvbrew.github.io/EdgeCase/

## The problem

You test the happy path, and maybe the empty string. The crash in production
comes from the username that's 10,000 characters, the `Double` that's `.nan`,
the array with 1,000 elements, the right-to-left display name. Writing those
fixtures by hand is tedious enough that nobody does it consistently.

## What it does

`@EdgeCases` inspects the stored properties of a struct (or the cases of an
enum) and synthesizes `static var edgeCases: [Self]` at compile time:

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
    try render(user)   // Int.min/.max ids, empty/huge/RTL/zero-width names…
}
```

Since flat structs of primitives aren't what real apps ship, the pieces that
came after the MVP are, I think, the interesting ones:

- **Optionals, collections, nesting, enums** — `nil` plus wrapped cases,
  empty/single/1,000-element collections, recursion into nested annotated
  types, every enum case with associated values varied.
- **Per-property overrides** — `@EdgeCase(.custom([0, 1, 149, 150]))` bounds
  `age` to its real domain instead of `Int.min`/`Int.max`;
  `@EdgeCase(.exclude)` pins cosmetic properties.
- **Strategies** — one-property-at-a-time (default, failures point at the
  culprit), `.minimal` (smallest set that still uses every edge value), or
  `.combinatorial` (cartesian product, capped at 1,000 with a compile-time
  warning).
- **Fixture composition** — `edgeCases(varying: .fixture())` keeps a
  realistic base instance and varies one property at a time, so you test one
  adversarial value inside an otherwise plausible model.
- **Test-framework sugar** — companion products for swift-testing (labeled
  `@Test(arguments:)` output, so a 10,000-character string doesn't flood the
  navigator) and XCTest (`XCTAssertNoThrow(forEachEdgeCase:)`, which keeps
  iterating past failures and reports every offending instance).
- **Loud failures** — unsupported property types are compile-time diagnostics
  with a suggested fix, never silent omissions.

## What 1.0 means

The macro signatures, the `EdgeCaseGeneratable`/`EdgeCaseComposable`
protocols, and the companion APIs are frozen; semver from here on, with an
API-breakage check in CI against the latest release tag. The concrete
generated *values* stay a quality surface that can grow in minor releases —
the stability policy is written down in
[API_STABILITY.md](https://github.com/pvbrew/EdgeCase/blob/main/API_STABILITY.md).

Swift 6, SPM-only, iOS 17+/macOS 10.15+.

## Feedback I'm looking for

- Which types do your models use that the built-in generators don't cover?
  (`Decimal`? `Data`? Ranges?)
- Is the combinatorial cap of 1,000 the right shape, or should it be
  configurable?
- Anyone testing with fixture libraries: does `edgeCases(varying:)` match how
  you'd actually want to compose realistic + adversarial data?

Thanks for reading — happy to answer anything here.
