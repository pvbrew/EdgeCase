// swift-testing integration. This module links Testing, so add the
// EdgeCaseTesting product to test targets only.
//
// `@Test(arguments: User.edgeCases)` needs nothing from this module — a
// `[Self]` of a Sendable type is a valid argument collection as-is. What it
// gets you is unreadable output: swift-testing labels each argument with its
// full description, and EdgeCase generates 10,000-character strings and
// 1,000-element collections on purpose.
#if canImport(Testing)
import EdgeCase
import Testing

/// One edge case paired with a short, single-line label, keeping
/// parameterized test output readable:
///
/// ```swift
/// @Test(arguments: User.labeledEdgeCases)
/// func rendering(_ edgeCase: LabeledEdgeCase<User>) throws {
///     try render(edgeCase.value)
/// }
/// ```
///
/// The test navigator then shows `[2] User(id: 0, username: "aaaaaaaa…`
/// instead of the instance's full description.
public struct LabeledEdgeCase<Value>: CustomTestStringConvertible {
    /// The instance's position in the list it was created from.
    public let index: Int
    /// The generated instance.
    public let value: Value
    /// `"[<index>] <abbreviated instance description>"`, precomputed so a
    /// label never re-renders a large instance.
    public let testDescription: String

    /// Wraps one element of a case list. `index` is only a display ordinal;
    /// it does not need to point into any particular collection.
    public init(index: Int, value: Value) {
        self.index = index
        self.value = value
        self.testDescription = "[\(index)] \(edgeCaseDescription(of: value))"
    }
}

extension LabeledEdgeCase: Sendable where Value: Sendable {}

extension EdgeCaseGeneratable {
    /// The same instances as `edgeCases`, each wrapped with a readable label
    /// for `@Test(arguments:)`.
    public static var labeledEdgeCases: [LabeledEdgeCase<Self>] {
        edgeCases.enumerated().map { LabeledEdgeCase(index: $0.offset, value: $0.element) }
    }
}

extension EdgeCaseComposable {
    /// The same instances as `edgeCases(varying:)`, each wrapped with a
    /// readable label — fixture composition and short labels together:
    ///
    /// ```swift
    /// @Test(arguments: User.labeledEdgeCases(varying: .fixture()))
    /// func rendering(_ edgeCase: LabeledEdgeCase<User>) throws {
    ///     try render(edgeCase.value)   // realistic user, one adversarial
    /// }                                // field, readable navigator label
    /// ```
    public static func labeledEdgeCases(varying base: Self) -> [LabeledEdgeCase<Self>] {
        edgeCases(varying: base).enumerated().map { LabeledEdgeCase(index: $0.offset, value: $0.element) }
    }
}
#endif
