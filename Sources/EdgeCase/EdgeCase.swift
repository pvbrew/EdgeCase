// The Swift Programming Language
// https://docs.swift.org/swift-book

/// A type that can supply boundary and adversarial instances of itself.
///
/// `@EdgeCases` generates this conformance for you, and recurses into stored
/// properties whose types conform to it. `Date`, `URL`, and `UUID` conform
/// out of the box. Conform manually to bring other types the macro has no
/// generator for — including ones you don't own — into edge case generation:
///
/// ```swift
/// extension Decimal: EdgeCaseGeneratable {
///     public static var edgeCases: [Decimal] {
///         [0, .greatestFiniteMagnitude, .leastFiniteMagnitude]
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

/// A type whose edge cases can be composed around a realistic base instance
/// — the integration point for fixture-style libraries.
///
/// `@EdgeCases` generates the conformance for structs (not enums: a base
/// enum value is a single case, and its adversaries are simply the other
/// cases in `edgeCases`). Conform manually to compose types the macro
/// does not generate for:
///
/// ```swift
/// let user = User.fixture()                        // realistic, yours
/// for case in User.edgeCases(varying: user) {      // adversarial, EdgeCase's
///     try render(case)
/// }
/// ```
public protocol EdgeCaseComposable: EdgeCaseGeneratable {
    /// Instances that keep `base`'s values while one property at a time
    /// takes its edge cases, so each returned instance is a realistic model
    /// carrying exactly one adversarial value.
    static func edgeCases(varying base: Self) -> [Self]
}

/// An abbreviated, single-line description of a generated instance, safe to
/// embed in test failure messages and parameterized-test labels: newlines are
/// collapsed and anything past `maxLength` characters is elided, so a
/// 10,000-character string edge case cannot flood test output.
///
/// The companion products use this to label cases; call it yourself when
/// building custom failure messages:
///
/// ```swift
/// XCTFail("rendering failed for \(edgeCaseDescription(of: user))")
/// ```
public func edgeCaseDescription<T>(of instance: T, maxLength: Int = 80) -> String {
    var description = String(describing: instance)
        .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        .joined(separator: " ")
    if maxLength > 0, description.count > maxLength {
        description = description.prefix(maxLength - 1) + "…"
    }
    return description
}

/// How `@EdgeCases` combines the edge cases of individual properties into
/// generated instances.
public enum EdgeCaseStrategy: Sendable {
    /// One property is varied through its edge cases at a time while every
    /// other property holds its baseline value. The instance count is the
    /// sum of each property's edge cases, and a failing instance points
    /// directly at the property to blame. The default.
    case oneAtATime

    /// Every property takes an edge case in every instance: instance *i*
    /// mixes the *i*-th edge case of each property, cycling properties with
    /// fewer cases. The instance count is the largest single property's
    /// case count — the smallest set that still uses every edge value.
    case minimal

    /// The cartesian product of every property's edge cases. Exhaustive but
    /// explosive: generation is capped at 1,000 instances, with a
    /// compile-time warning when the cap is exceeded.
    case combinatorial
}

/// A per-property override for `@EdgeCases`, attached via the ``EdgeCase(_:)``
/// marker. Values passed to `custom` are never evaluated at runtime; the
/// macro splices their source text into the generated `edgeCases`.
public struct EdgeCaseOverride: Sendable {
    /// Replaces the property's generated edge cases with an explicit list.
    /// The first value doubles as the property's baseline. The elements must
    /// be valid expressions of the property's type; the list must be written
    /// as an array literal.
    public static func custom<T>(_ values: [T]) -> EdgeCaseOverride {
        EdgeCaseOverride()
    }

    /// Skips the property: it holds its default value (if it has one) or its
    /// type's baseline in every generated instance, and is never varied.
    public static var exclude: EdgeCaseOverride {
        EdgeCaseOverride()
    }

    private init() {}
}

/// Overrides how `@EdgeCases` treats one stored property:
///
/// ```swift
/// @EdgeCases
/// struct Patient {
///     @EdgeCase(.custom([0, 1, 149, 150]))
///     let age: Int                       // bounded domain, not Int.min/.max
///
///     @EdgeCase(.exclude)
///     var avatar: String = "person"      // held at its default, never varied
///
///     let notes: String                  // generated as usual
/// }
/// ```
///
/// The attribute expands to nothing — it is a compile-time marker read by
/// `@EdgeCases` on the containing type. It has no effect on computed,
/// `static`, `lazy`, or fixed (`let` with a default value) properties, and
/// cannot be attached to enum associated values.
@attached(peer)
public macro EdgeCase(_ override: EdgeCaseOverride) =
    #externalMacro(module: "EdgeCaseMacros", type: "EdgeCaseOverrideMacro")

/// Generates a `static var edgeCases: [Self]` containing boundary and
/// adversarial instances of the attached struct or enum, plus a
/// `static var edgeCaseBaseline: Self` and an `EdgeCaseGeneratable`
/// conformance so annotated types can nest inside each other.
///
/// Structs additionally get `static func edgeCases(varying base: Self)` and
/// the ``EdgeCaseComposable`` conformance declaring it, which composes
/// realistic and adversarial data: one property at a time
/// takes its edge cases while every other property keeps the value from
/// `base` — pass an instance from your fixtures library to test adversarial
/// values in an otherwise realistic model. Composition is always
/// one-property-at-a-time, whatever `strategy` says, because holding the
/// rest of the instance at `base` is the point:
///
/// ```swift
/// @Test(arguments: User.edgeCases(varying: .fixture()))
/// func rendering(user: User) throws {
///     try render(user)   // realistic user, one adversarial field
/// }
/// ```
///
/// Each stored property (or enum associated value) contributes its type's
/// edge cases; `strategy` controls how they are combined into instances —
/// one property varied at a time (``EdgeCaseStrategy/oneAtATime``, the
/// default), every property varied at once (``EdgeCaseStrategy/minimal``),
/// or the full cartesian product capped at 1,000 instances
/// (``EdgeCaseStrategy/combinatorial``). Exact duplicates are removed. For
/// enums, every case is generated.
///
/// Supported property types (v0.4):
/// - `Int`, `Int8`, `Int16`, `Int32`, `Int64` — `.min`, `.max`, `0`, `-1`
/// - `Double`, `Float` — `±.greatestFiniteMagnitude`, `0`, `.nan`, `.infinity`
/// - `String` — empty, single char, 10,000 chars, whitespace-only, emoji,
///   right-to-left text, zero-width characters, combining diacritics
/// - `Bool` — both values
/// - `Optional<T>` — `nil` plus the edge cases of `T`
/// - `Array<T>` — empty, single element, 1,000 elements, all-edge-case elements
/// - `Set<T>` / `Dictionary<K, V>` — empty, 1,000 elements
/// - `Date`, `URL`, `UUID` — via bundled ``EdgeCaseGeneratable`` conformances
/// - any named type conforming to ``EdgeCaseGeneratable`` (such as another
///   `@EdgeCases` type) — its own `edgeCases` are recursed into
///
/// Individual properties can be bounded or skipped with the ``EdgeCase(_:)``
/// attribute. Constants with a default value (`let x = 1`) keep their fixed
/// value; computed, `static`, and `lazy` properties are ignored. A property
/// whose type has no generator keeps its default value with a compile-time
/// warning when it has one, and is an error otherwise.
@attached(member, names: named(edgeCases), named(edgeCaseBaseline), named(edgeCases(varying:)))
@attached(extension, conformances: EdgeCaseGeneratable, EdgeCaseComposable)
public macro EdgeCases(strategy: EdgeCaseStrategy = .oneAtATime) =
    #externalMacro(module: "EdgeCaseMacros", type: "EdgeCasesMacro")
