# API Stability

As of **1.0.0**, EdgeCase follows [Semantic Versioning](https://semver.org). This
document records the API review that froze the 1.0 surface: what is locked, what
may still evolve in minor releases, and the reasoning behind the line between
the two.

## The locked public API

Breaking any of the following requires a major version bump.

### `EdgeCase` (the module app and test targets import)

| Symbol | Locked signature |
| --- | --- |
| `@EdgeCases` | `@attached(member) @attached(extension) macro EdgeCases(strategy: EdgeCaseStrategy = .oneAtATime)` |
| `@EdgeCase` | `@attached(peer) macro EdgeCase(_ override: EdgeCaseOverride)` |
| `EdgeCaseGeneratable` | `static var edgeCases: [Self] { get }` + `static var edgeCaseBaseline: Self { get }` (defaulted to the first edge case) |
| `EdgeCaseComposable` | `: EdgeCaseGeneratable` + `static func edgeCases(varying base: Self) -> [Self]` |
| `EdgeCaseStrategy` | `enum` with cases `oneAtATime`, `minimal`, `combinatorial`; `Sendable` |
| `EdgeCaseOverride` | `struct` with `static func custom<T>(_ values: [T])` and `static var exclude`; `Sendable` |
| `edgeCaseDescription(of:maxLength:)` | `func edgeCaseDescription<T>(of instance: T, maxLength: Int = 80) -> String` |
| `Date`, `URL`, `UUID` | bundled `EdgeCaseGeneratable` conformances |

Members the macro generates on annotated types are part of the contract:
`static var edgeCases: [Self]`, `static var edgeCaseBaseline: Self`, both
protocol conformances, and — for structs — `static func edgeCases(varying:)`.
Generated members mirror the type's `public`/`package` access level and its
`nonisolated` modifier.

### `EdgeCaseTesting` (test targets only)

| Symbol | Locked signature |
| --- | --- |
| `LabeledEdgeCase<Value>` | `struct` with `index: Int`, `value: Value`, `testDescription: String`, `init(index:value:)`; `CustomTestStringConvertible`; `Sendable` when `Value` is |
| `labeledEdgeCases` | `static var labeledEdgeCases: [LabeledEdgeCase<Self>]` on `EdgeCaseGeneratable` |
| `labeledEdgeCases(varying:)` | `static func labeledEdgeCases(varying base: Self) -> [LabeledEdgeCase<Self>]` on `EdgeCaseComposable` |

### `EdgeCaseXCTest` (test targets only)

| Symbol | Locked signature |
| --- | --- |
| `XCTAssertNoThrow(forEachEdgeCase:_:file:line:_:)` | runs the body per generated case, continues past failures |
| `XCTAssertNoThrow(forEach:_:file:line:_:)` | same, over an explicit sequence |

### Behavioral contracts

These behaviors are part of the locked API, not implementation details:

- **`.oneAtATime`** varies exactly one property per instance while the others
  hold their baseline; **`.minimal`** produces as many instances as the longest
  single property's case list; **`.combinatorial`** produces the cartesian
  product, capped at 1,000 instances.
- **Exact duplicates are removed** from generated case lists.
- **`edgeCases(varying:)`** is always one-property-at-a-time and passes
  excluded/unsupported properties through from `base`, whatever `strategy` says.
- **`@EdgeCase(.custom([...]))`** splices the written expressions in at compile
  time; the first value doubles as the property's baseline.
- **`@EdgeCase(.exclude)`** pins a property to its default value, or to its
  type's baseline when it has none.
- **Unsupported property types** are compile-time errors (or warnings when a
  default value exists to fall back on) — never silent omissions.
- Failure messages and test labels abbreviate instance descriptions so
  deliberately huge values cannot flood test output.

## What may change in a minor release

Additions and refinements that do not break source compatibility:

- **The generated case values themselves.** The concrete edge cases for a type
  (which strings, which dates, how many collection elements) are a quality
  surface, not an API: minor releases may add new adversarial values, reorder
  case lists, or refine existing values, which also changes case counts. Write
  tests against behaviors (`contains { $0.karma.isNaN }`), not against exact
  indices or counts. The two anchors that will not move: the first element of a
  built-in generator's list stays its neutral baseline, and every built-in
  generator keeps covering at least the categories documented in the README
  table for its type.
- **New API.** New strategies, overrides, built-in generators, protocol
  conformances for further Foundation types, and new companion helpers arrive
  as additive changes.
- **Diagnostics.** Message wording, diagnostic IDs, and severity may improve at
  any time (an error will not silently become a warning for code that should
  not compile).
- **Generated source text.** The exact expansion the macro emits (variable
  names, `map` vs. loop, formatting) is an implementation detail; only the
  declared members and their semantics are contractual.

## Platforms and toolchain

Swift 6.0+ (swift-tools 6.0), iOS 17+ / macOS 10.15+, SPM only. Raising the
minimum Swift or platform requirement is treated as a breaking change and
reserved for major versions.

## Enforcement

CI runs `swift package diagnose-api-breaking-changes` against the latest
release tag on every pull request once a `1.x` tag exists, so an accidental
signature change fails the build before it can ship.
