# Changelog

All notable changes to EdgeCase are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and from 1.0.0
onward the project adheres to [Semantic Versioning](https://semver.org)
— see [API_STABILITY.md](API_STABILITY.md) for exactly what the version
number promises.

## [1.0.0] — 2026-07-16

The stable release: the macro signatures, protocols, and companion APIs are
frozen. Releases before 1.0.0 were tagged with two-component versions
(`0.1`–`0.4`), which SPM does not resolve as versions; 1.0.0 is the first tag
installable with `from:`.

### Added

- `labeledEdgeCases(varying:)` in `EdgeCaseTesting` — composed cases
  (realistic fixture, one adversarial property at a time) with the same short
  navigator labels `labeledEdgeCases` gives the plain list.
- [API_STABILITY.md](API_STABILITY.md): the locked public surface, the
  behavioral contracts behind it, and what may still evolve in minor releases.
- DocC catalogs for `EdgeCaseTesting` and `EdgeCaseXCTest`; documentation for
  all three modules is now built as one combined archive.
- Hosted documentation: a GitHub Pages workflow publishes the DocC archive on
  every release tag, and `.spi.yml` requests docs builds on the Swift Package
  Index.
- CI job that runs `swift package diagnose-api-breaking-changes` against the
  latest release tag on every pull request, enforcing the semver commitment
  mechanically.

### Changed

- Doc comments and articles no longer reference roadmap version numbers.

## [0.4] — 2026-07-15

### Added

- `EdgeCaseXCTest` product: `XCTAssertNoThrow(forEachEdgeCase:)` and
  `XCTAssertNoThrow(forEach:)` — iterate every case, report every failure,
  abbreviate huge instances.
- `EdgeCaseTesting` product: `LabeledEdgeCase` and `labeledEdgeCases` for
  readable `@Test(arguments:)` labels in swift-testing.
- `EdgeCaseComposable` protocol and generated `edgeCases(varying:)` — compose
  adversarial values around a realistic fixture instance.
- `edgeCaseDescription(of:maxLength:)` for abbreviated instance descriptions
  in custom failure messages.
- GitHub Actions CI: macOS (current + oldest supported Xcode), Linux, the
  example app on an iOS simulator, and a DocC build.
- DocC catalog for the `EdgeCase` module with Getting Started and Testing
  Integration articles.
- Example app test target demonstrating both framework integrations.

## [0.3] — 2026-07-15

### Added

- `@EdgeCase(.custom([...]))` — bound a property to its real domain.
- `@EdgeCase(.exclude)` — pin a property to its default, never vary it.
- Generation strategies: `.oneAtATime` (default), `.minimal`, and
  `.combinatorial` capped at 1,000 instances with a compile-time warning.
- `EdgeCaseGeneratable` conformances for `Date`, `URL`, and `UUID`.
- Compile-time diagnostics for unsupported types, ineffective overrides, and
  the combinatorial cap.

## [0.2] — 2026-07-15

### Added

- `Optional<T>`: `nil` plus every wrapped edge case.
- Collections: `Array` (empty, single, 1,000 elements, all-edge-case
  elements), `Set`, and `Dictionary` (empty, 1,000 entries).
- String unicode adversaries: emoji (ZWJ, skin tone, flag), right-to-left
  text, zero-width characters, combining diacritics.
- Nested custom types via `EdgeCaseGeneratable` recursion.
- Enum support: every case, associated values varied.

## [0.1] — 2026-07-13

### Added

- `@EdgeCases` attached member macro generating `static var edgeCases: [Self]`
  for flat structs.
- Built-in generators: integer family (`.min`, `.max`, `0`, `-1`),
  `Double`/`Float` (`±.greatestFiniteMagnitude`, `0`, `.nan`, `.infinity`),
  `String` (empty, single character, 10,000 characters, whitespace-only), and
  `Bool`.
- Macro-expansion test suite, README, MIT license.

[1.0.0]: https://github.com/pvbrew/EdgeCase/releases/tag/1.0.0
[0.4]: https://github.com/pvbrew/EdgeCase/releases/tag/0.4
[0.3]: https://github.com/pvbrew/EdgeCase/releases/tag/0.3
[0.2]: https://github.com/pvbrew/EdgeCase/releases/tag/0.2
[0.1]: https://github.com/pvbrew/EdgeCase/releases/tag/0.1
