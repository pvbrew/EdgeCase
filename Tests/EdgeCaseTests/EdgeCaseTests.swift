import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is
// not available when cross-compiling.
#if canImport(EdgeCaseMacros)
import EdgeCaseMacros

let testMacros: [String: Macro.Type] = [
    "EdgeCases": EdgeCasesMacro.self,
]

final class EdgeCaseTests: XCTestCase {

    // MARK: - Generation

    func testIntProperties() {
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
                    [
                        Self(x: Int.min, y: 0),
                        Self(x: Int.max, y: 0),
                        Self(x: 0, y: 0),
                        Self(x: -1, y: 0),
                        Self(x: 0, y: Int.min),
                        Self(x: 0, y: Int.max),
                        Self(x: 0, y: -1),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFixedWidthIntegerProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Sample {
                let value: Int8
            }
            """,
            expandedSource: """
            struct Sample {
                let value: Int8

                static var edgeCases: [Self] {
                    [
                        Self(value: Int8.min),
                        Self(value: Int8.max),
                        Self(value: 0),
                        Self(value: -1),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testFloatingPointProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Measurement {
                let value: Double
            }
            """,
            expandedSource: """
            struct Measurement {
                let value: Double

                static var edgeCases: [Self] {
                    [
                        Self(value: -Double.greatestFiniteMagnitude),
                        Self(value: Double.greatestFiniteMagnitude),
                        Self(value: 0),
                        Self(value: Double.nan),
                        Self(value: Double.infinity),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testStringProperties() {
        assertMacroExpansion(
            #"""
            @EdgeCases
            struct Message {
                let text: String
            }
            """#,
            expandedSource: #"""
            struct Message {
                let text: String

                static var edgeCases: [Self] {
                    [
                        Self(text: ""),
                        Self(text: "a"),
                        Self(text: String(repeating: "a", count: 10_000)),
                        Self(text: " \t\n"),
                    ]
                }
            }
            """#,
            macros: testMacros
        )
    }

    func testBoolProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Flag {
                let isOn: Bool
            }
            """,
            expandedSource: """
            struct Flag {
                let isOn: Bool

                static var edgeCases: [Self] {
                    [
                        Self(isOn: true),
                        Self(isOn: false),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMixedPropertiesDeduplicateBaselineInstances() {
        assertMacroExpansion(
            #"""
            @EdgeCases
            struct User {
                let id: Int
                let name: String
                var isActive: Bool
            }
            """#,
            expandedSource: #"""
            struct User {
                let id: Int
                let name: String
                var isActive: Bool

                static var edgeCases: [Self] {
                    [
                        Self(id: Int.min, name: "", isActive: false),
                        Self(id: Int.max, name: "", isActive: false),
                        Self(id: 0, name: "", isActive: false),
                        Self(id: -1, name: "", isActive: false),
                        Self(id: 0, name: "a", isActive: false),
                        Self(id: 0, name: String(repeating: "a", count: 10_000), isActive: false),
                        Self(id: 0, name: " \t\n", isActive: false),
                        Self(id: 0, name: "", isActive: true),
                    ]
                }
            }
            """#,
            macros: testMacros
        )
    }

    func testPublicStructGetsPublicEdgeCases() {
        assertMacroExpansion(
            """
            @EdgeCases
            public struct Score {
                public let points: Int
            }
            """,
            expandedSource: """
            public struct Score {
                public let points: Int

                public static var edgeCases: [Self] {
                    [
                        Self(points: Int.min),
                        Self(points: Int.max),
                        Self(points: 0),
                        Self(points: -1),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testSkipsNonGeneratedProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Config {
                static let shared = 1
                let retries: Int
                let environment = "prod"
                var timeout: Double { 30 }
                var verbose: Bool = false
            }
            """,
            expandedSource: """
            struct Config {
                static let shared = 1
                let retries: Int
                let environment = "prod"
                var timeout: Double { 30 }
                var verbose: Bool = false

                static var edgeCases: [Self] {
                    [
                        Self(retries: Int.min, verbose: false),
                        Self(retries: Int.max, verbose: false),
                        Self(retries: 0, verbose: false),
                        Self(retries: -1, verbose: false),
                        Self(retries: 0, verbose: true),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testMultipleBindingsShareTypeAnnotation() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Point {
                let x, y: Int
            }
            """,
            expandedSource: """
            struct Point {
                let x, y: Int

                static var edgeCases: [Self] {
                    [
                        Self(x: Int.min, y: 0),
                        Self(x: Int.max, y: 0),
                        Self(x: 0, y: 0),
                        Self(x: -1, y: 0),
                        Self(x: 0, y: Int.min),
                        Self(x: 0, y: Int.max),
                        Self(x: 0, y: -1),
                    ]
                }
            }
            """,
            macros: testMacros
        )
    }

    func testEmptyStruct() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Empty {
            }
            """,
            expandedSource: """
            struct Empty {

                static var edgeCases: [Self] {
                    []
                }
            }
            """,
            macros: testMacros
        )
    }

    // MARK: - Diagnostics

    func testDiagnosesNonStruct() {
        assertMacroExpansion(
            """
            @EdgeCases
            enum Direction {
                case north
            }
            """,
            expandedSource: """
            enum Direction {
                case north
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' can only be attached to a struct",
                    line: 1,
                    column: 1
                )
            ],
            macros: testMacros
        )
    }

    func testDiagnosesUnsupportedType() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Event {
                let createdAt: Date
            }
            """,
            expandedSource: """
            struct Event {
                let createdAt: Date
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' has no generator for type 'Date' of stored property 'createdAt' (supported: Int, Int8, Int16, Int32, Int64, Double, Float, String, Bool)",
                    line: 3,
                    column: 9
                )
            ],
            macros: testMacros
        )
    }

    func testDiagnosesMissingTypeAnnotation() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Counter {
                var count = 0
            }
            """,
            expandedSource: """
            struct Counter {
                var count = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "stored property 'count' needs an explicit type annotation to be included in edge case generation",
                    line: 3,
                    column: 9
                )
            ],
            macros: testMacros
        )
    }
}
#endif
