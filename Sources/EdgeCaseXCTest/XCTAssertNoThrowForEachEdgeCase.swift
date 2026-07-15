// XCTest integration. This module links XCTest, so add the EdgeCaseXCTest
// product to test targets only.
#if canImport(XCTest)
import EdgeCase
import XCTest

/// Runs `body` once for every edge case of `type`, recording one test
/// failure per instance that throws:
///
/// ```swift
/// func testRenderingSurvivesEdgeCases() {
///     XCTAssertNoThrow(forEachEdgeCase: User.self) { user in
///         try render(user)
///     }
/// }
/// ```
///
/// Unlike `XCTAssertNoThrow(_:)`, iteration continues past a failing case,
/// so a single run reports every offending instance. Each failure message
/// names the case's position in `edgeCases` and an abbreviated description
/// of the instance — a 10,000-character username cannot flood the log.
public func XCTAssertNoThrow<T: EdgeCaseGeneratable>(
    forEachEdgeCase type: T.Type,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: (T) throws -> Void
) {
    XCTAssertNoThrow(forEach: type.edgeCases, message(), file: file, line: line, body)
}

/// Runs `body` once for every instance in `cases`, recording one test
/// failure per instance that throws. Use it with an explicit case list, such
/// as edge cases composed around a fixture:
///
/// ```swift
/// XCTAssertNoThrow(forEach: User.edgeCases(varying: .fixture())) { user in
///     try render(user)
/// }
/// ```
public func XCTAssertNoThrow<S: Sequence>(
    forEach cases: S,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ body: (S.Element) throws -> Void
) {
    for (index, instance) in cases.enumerated() {
        do {
            try body(instance)
        } catch {
            let prefix = message()
            XCTFail(
                "\(prefix.isEmpty ? "" : prefix + " — ")edge case [\(index)] "
                    + "\(edgeCaseDescription(of: instance)) threw \(error)",
                file: file,
                line: line
            )
        }
    }
}
#endif
