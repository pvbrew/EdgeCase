import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(EdgeCaseMacros)
import EdgeCaseMacros

let testMacros: [String: Macro.Type] = [
    "EdgeCases": EdgeCasesMacro.self,
]
#endif

final class EdgeCaseTests: XCTestCase {
    func testMacro() throws {
        #if canImport(EdgeCaseMacros)
        assertMacroExpansion(
            """
            @EdgeCases
            struct Coordinate {
                let x: Int
                let y: Int
            }
            """,
            expandedSource: """
            struct Coordinate {
                let x: Int
                let y: Int

                static var edgeCases: [Self] {
                    []
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
