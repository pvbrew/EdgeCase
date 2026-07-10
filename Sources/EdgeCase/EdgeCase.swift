// The Swift Programming Language
// https://docs.swift.org/swift-book

/// Generates a `static var edgeCases: [Self]` containing boundary and
/// adversarial instances of the attached struct.
///
/// Each stored property is varied through its type's edge cases while the
/// remaining properties hold a baseline value (`0`, `""`, `false`), so the
/// number of generated instances grows linearly with the number of
/// properties. Exact duplicates are removed.
///
/// Supported property types (v0.1): `Int`, `Int8`, `Int16`, `Int32`,
/// `Int64`, `Double`, `Float`, `String`, `Bool`. Constants with a default
/// value (`let x = 1`) keep their fixed value; computed, `static`, and
/// `lazy` properties are ignored.
@attached(member, names: named(edgeCases))
public macro EdgeCases() = #externalMacro(module: "EdgeCaseMacros", type: "EdgeCasesMacro")
