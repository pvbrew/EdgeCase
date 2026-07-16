---
title: "The Test Cases You Forgot: Generating Adversarial Swift Fixtures with a Macro"
published: false
description: "EdgeCase 1.0 is a Swift macro that generates the boundary and adversarial instances of your own types — the empty string, the Int.max, the 10,000-character username — in one line."
tags: swift, testing, ios, opensource
---

<!-- dev.to front matter above; strip it when publishing on Medium. -->

Your test suite has a `User(id: 1, name: "Ada", isActive: true)` in it
somewhere. It renders fine. It always renders fine.

The user who crashes your app has a 10,000-character username pasted from a
note-taking app, a karma score that divided by zero into `.nan` three
releases ago, no bio, 1,000 tags, and a display name written right-to-left.
You did not write that fixture. Nobody writes that fixture — by hand.

## Fixtures are a coverage problem disguised as a typing problem

Everyone knows the boundary values matter. `Int.min`, `Int.max`, `0`, `-1`.
Empty string, huge string, whitespace-only string, combining diacritics.
`nil`. Empty array, enormous array. `.distantPast`. We can all recite the
list — which is exactly why writing it out for every model, on every model
change, is work that reliably doesn't happen.

That list is mechanical. Mechanical work is what compilers are for, and
Swift macros run in the compiler.

## One annotation

[EdgeCase](https://github.com/pvbrew/EdgeCase) is a Swift macro package that
inspects the stored properties of a struct (or the cases of an enum) and
synthesizes the adversarial instances at compile time:

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

That's the whole integration. `@EdgeCases` generates a
`static var edgeCases: [Self]` — `Int.min` and `Int.max` ids; empty,
single-character, 10,000-character, whitespace-only, emoji, right-to-left,
zero-width, and combining-diacritic names; both booleans — and swift-testing's
parameterized tests turn each instance into its own test case, so a failure
names the exact adversarial value.

Under the default strategy, one property varies at a time while the others
hold a neutral baseline. When the 10,000-character name breaks your layout
code, the failing instance points straight at `name`.

## Real models aren't flat structs of primitives

The generators recurse. Optionals contribute `nil` plus every wrapped case;
arrays contribute empty, single-element, 1,000-element, and all-edge-case
variants; annotated types nest inside each other; enums produce every case
with associated values varied; `Date`, `URL`, and `UUID` ship with
conformances (epoch and Y2038 rollover, punycode hosts and `file://`, the
nil UUID).

Two things make it usable on production models rather than toy structs:

**Overrides.** An `age` property should be tested at 0, 13, and 118 — not at
`Int.min`, which no validation layer should ever see:

```swift
@EdgeCases
struct Patient {
    @EdgeCase(.custom([0, 1, 149, 150]))
    let age: Int                        // your domain, exactly on its boundaries

    @EdgeCase(.exclude)
    var avatar: String = "person"       // cosmetic; varying it is noise

    let notes: String                   // generated as usual
}
```

**Strategies.** The default varies one property at a time, so case count
grows linearly. `.minimal` packs every edge value into the fewest instances —
the smoke-test set. `.combinatorial` emits the cartesian product for
cross-field validation bugs, capped at 1,000 instances with a compile-time
warning, because a 12-property model's product is not a test suite, it's a
space heater.

## Realistic body, one adversarial organ

Generated instances are all-neutral except the varied property. That's ideal
for blame assignment, but sometimes you want the opposite: a *realistic*
instance — from your fixtures library, or a hand-rolled `.fixture()` factory
— with exactly one adversarial value swapped in:

```swift
@Test(arguments: User.labeledEdgeCases(varying: .fixture()))
func rendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    try render(edgeCase.value)   // Ada's profile, one hostile field at a time
}
```

`labeledEdgeCases` is the swift-testing companion module doing one more job:
labeling each case with a short `[3] User(id: 92233…` instead of letting a
deliberately huge instance description flood the test navigator. XCTest gets
its own sugar — `XCTAssertNoThrow(forEachEdgeCase: User.self)` — which keeps
iterating past failures and reports every offending instance in one run.

## Failing loudly is a feature

A fixture generator that silently skips a property it doesn't understand is
worse than none — you'd trust coverage you don't have. If a property's type
has no generator, no conformance, and no override, that's a compile-time
error naming the property and the fix. If it has a default value to fall
back on, it's a warning. The `.combinatorial` cap warns before it truncates.

## What 1.0 means

I shipped the MVP a few versions ago; 1.0 is the boring-on-purpose release:
the macro signatures, the `EdgeCaseGeneratable` and `EdgeCaseComposable`
protocols, and the companion APIs are frozen, with the policy written down in
[API_STABILITY.md](https://github.com/pvbrew/EdgeCase/blob/main/API_STABILITY.md)
and a CI job that diffs the public API against the latest release tag on
every pull request. The generated *values* deliberately stay a quality
surface — minor releases can add new adversaries, which is the point of
depending on a library like this: your fixtures get meaner over time without
you editing a test.

Swift 6, SPM-only, iOS 17+/macOS 10.15+, MIT.

- **Repo:** https://github.com/pvbrew/EdgeCase
- **Docs:** https://pvbrew.github.io/EdgeCase/
- **Example app** (SwiftUI screen rendering every generated case, plus both
  test-framework integrations):
  [Examples/EdgeCaseExample](https://github.com/pvbrew/EdgeCase/tree/main/Examples/EdgeCaseExample)

If your models use types the built-in generators don't cover, or your edge
cases are meaner than mine, I want to hear about it — issues and PRs welcome.
