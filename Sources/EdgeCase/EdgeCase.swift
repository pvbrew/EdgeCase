// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A type that can supply boundary and adversarial instances of itself.
///
/// `@EdgeCases` generates this conformance for you, and recurses into stored
/// properties whose types conform to it. Conform manually to bring types the
/// macro has no generator for — including ones you don't own, like `Date` or
/// `URL` — into edge case generation:
///
/// ```swift
/// extension Date: EdgeCaseGeneratable {
///     public static var edgeCases: [Date] {
///         [.distantPast, .distantFuture, Date(timeIntervalSince1970: 0)]
///     }
/// }
/// ```
public protocol EdgeCaseGeneratable {
    /// Boundary and adversarial instances of this type.
    static var edgeCases: [Self] { get }

    /// The neutral instance used for this type while another property is
    /// being varied. Defaults to the first element of `edgeCases`.
    static var edgeCaseBaseline: Self { get }
}

extension EdgeCaseGeneratable {
    public static var edgeCaseBaseline: Self {
        guard let first = edgeCases.first else {
            preconditionFailure(
                "'edgeCases' of '\(Self.self)' is empty; provide an explicit 'edgeCaseBaseline' or a non-empty 'edgeCases'."
            )
        }
        return first
    }
}

/// Generates a `static var edgeCases: [Self]` containing boundary and
/// adversarial instances of the attached struct or enum, plus a
/// `static var edgeCaseBaseline: Self` and an `EdgeCaseGeneratable`
/// conformance so annotated types can nest inside each other.
///
/// Each stored property (or enum associated value) is varied through its
/// type's edge cases while the remaining ones hold a baseline value (`0`,
/// `""`, `false`, `nil`, `[]`), so the number of generated instances grows
/// linearly. Exact duplicates are removed. For enums, every case is
/// generated.
///
/// Supported property types (v0.2):
/// - `Int`, `Int8`, `Int16`, `Int32`, `Int64` — `.min`, `.max`, `0`, `-1`
/// - `Double`, `Float` — `±.greatestFiniteMagnitude`, `0`, `.nan`, `.infinity`
/// - `String` — empty, single char, 10,000 chars, whitespace-only, emoji,
///   right-to-left text, zero-width characters, combining diacritics
/// - `Bool` — both values
/// - `Optional<T>` — `nil` plus the edge cases of `T`
/// - `Array<T>` — empty, single element, 1,000 elements, all-edge-case elements
/// - `Set<T>` / `Dictionary<K, V>` — empty, 1,000 elements
/// - any named type conforming to ``EdgeCaseGeneratable`` (such as another
///   `@EdgeCases` type) — its own `edgeCases` are recursed into
///
/// Constants with a default value (`let x = 1`) keep their fixed value;
/// computed, `static`, and `lazy` properties are ignored.
@attached(member, names: named(edgeCases), named(edgeCaseBaseline))
@attached(extension, conformances: EdgeCaseGeneratable)
public macro EdgeCases() = #externalMacro(module: "EdgeCaseMacros", type: "EdgeCasesMacro")
