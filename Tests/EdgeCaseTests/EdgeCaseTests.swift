import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is
// not available when cross-compiling.
#if canImport(EdgeCaseMacros)
import EdgeCaseMacros

/// Declaring the conformance in the spec lets the test harness exercise the
/// extension role the way the compiler does.
let testMacros: [String: MacroSpec] = [
    "EdgeCases": MacroSpec(type: EdgeCasesMacro.self, conformances: ["EdgeCaseGeneratable"]),
]

final class EdgeCaseTests: XCTestCase {

    // MARK: - Primitive generation

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

                static var edgeCaseBaseline: Self {
                    Self(x: 0, y: 0)
                }
            }

            extension Coordinate: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
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

                static var edgeCaseBaseline: Self {
                    Self(value: 0)
                }
            }

            extension Sample: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
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

                static var edgeCaseBaseline: Self {
                    Self(value: 0)
                }
            }

            extension Measurement: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testStringPropertiesIncludeUnicodeAdversaries() {
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
                        Self(text: "\u{1F9D1}\u{200D}\u{1F680}\u{1F44D}\u{1F3FD}\u{1F1EC}\u{1F1F7}"),
                        Self(text: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{05E9}\u{05DC}\u{05D5}\u{05DD}"),
                        Self(text: "a\u{200B}b\u{200C}c\u{200D}d"),
                        Self(text: "Cafe\u{0301}"),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(text: "")
                }
            }

            extension Message: EdgeCaseGeneratable {
            }
            """#,
            macroSpecs: testMacros
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

                static var edgeCaseBaseline: Self {
                    Self(isOn: false)
                }
            }

            extension Flag: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
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
                        Self(id: 0, name: "\u{1F9D1}\u{200D}\u{1F680}\u{1F44D}\u{1F3FD}\u{1F1EC}\u{1F1F7}", isActive: false),
                        Self(id: 0, name: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{05E9}\u{05DC}\u{05D5}\u{05DD}", isActive: false),
                        Self(id: 0, name: "a\u{200B}b\u{200C}c\u{200D}d", isActive: false),
                        Self(id: 0, name: "Cafe\u{0301}", isActive: false),
                        Self(id: 0, name: "", isActive: true),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(id: 0, name: "", isActive: false)
                }
            }

            extension User: EdgeCaseGeneratable {
            }
            """#,
            macroSpecs: testMacros
        )
    }

    func testPublicStructGetsPublicMembers() {
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

                public static var edgeCaseBaseline: Self {
                    Self(points: 0)
                }
            }

            extension Score: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
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

                static var edgeCaseBaseline: Self {
                    Self(retries: 0, verbose: false)
                }
            }

            extension Config: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
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

                static var edgeCaseBaseline: Self {
                    Self(x: 0, y: 0)
                }
            }

            extension Point: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
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
                    [
                        Self(),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self()
                }
            }

            extension Empty: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Optionals

    func testOptionalProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Form {
                let age: Int?
                var bonus: Optional<Int>
            }
            """,
            expandedSource: """
            struct Form {
                let age: Int?
                var bonus: Optional<Int>

                static var edgeCases: [Self] {
                    [
                        Self(age: nil, bonus: nil),
                        Self(age: Int.min, bonus: nil),
                        Self(age: Int.max, bonus: nil),
                        Self(age: 0, bonus: nil),
                        Self(age: -1, bonus: nil),
                        Self(age: nil, bonus: Int.min),
                        Self(age: nil, bonus: Int.max),
                        Self(age: nil, bonus: 0),
                        Self(age: nil, bonus: -1),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(age: nil, bonus: nil)
                }
            }

            extension Form: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Collections

    func testArrayProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Basket {
                let counts: [Int]
                let bytes: Array<Int8>
            }
            """,
            expandedSource: """
            struct Basket {
                let counts: [Int]
                let bytes: Array<Int8>

                static var edgeCases: [Self] {
                    [
                        Self(counts: [], bytes: []),
                        Self(counts: [0], bytes: []),
                        Self(counts: Array(repeating: 0, count: 1_000), bytes: []),
                        Self(counts: [Int.min, Int.max, 0, -1], bytes: []),
                        Self(counts: [], bytes: [0]),
                        Self(counts: [], bytes: Array(repeating: 0, count: 1_000)),
                        Self(counts: [], bytes: [Int8.min, Int8.max, 0, -1]),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(counts: [], bytes: [])
                }
            }

            extension Basket: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testDictionaryAndSetProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Catalog {
                let stock: [String: Int]
                let ids: Set<Int>
                let flags: Set<Bool>
            }
            """,
            expandedSource: """
            struct Catalog {
                let stock: [String: Int]
                let ids: Set<Int>
                let flags: Set<Bool>

                static var edgeCases: [Self] {
                    [
                        Self(stock: [:], ids: [], flags: []),
                        Self(stock: Dictionary(uniqueKeysWithValues: zip((0 ..< 1_000).map(String.init), repeatElement(0, count: 1_000))), ids: [], flags: []),
                        Self(stock: [:], ids: Set(0 ..< 1_000), flags: []),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(stock: [:], ids: [], flags: [])
                }
            }

            extension Catalog: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testOptionalArrayProperty() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Draft {
                let attachments: [Int]?
            }
            """,
            expandedSource: """
            struct Draft {
                let attachments: [Int]?

                static var edgeCases: [Self] {
                    [
                        Self(attachments: nil),
                        Self(attachments: []),
                        Self(attachments: [0]),
                        Self(attachments: Array(repeating: 0, count: 1_000)),
                        Self(attachments: [Int.min, Int.max, 0, -1]),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(attachments: nil)
                }
            }

            extension Draft: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Nested custom types

    func testNestedCustomTypeRecursesThroughEdgeCaseGeneratable() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Profile {
                let level: Int
                let address: Address
            }
            """,
            expandedSource: """
            struct Profile {
                let level: Int
                let address: Address

                static var edgeCases: [Self] {
                    [
                        Self(level: Int.min, address: Address.edgeCaseBaseline),
                        Self(level: Int.max, address: Address.edgeCaseBaseline),
                        Self(level: 0, address: Address.edgeCaseBaseline),
                        Self(level: -1, address: Address.edgeCaseBaseline),
                    ]
                    + Address.edgeCases.map {
                        Self(level: 0, address: $0)
                    }
                }

                static var edgeCaseBaseline: Self {
                    Self(level: 0, address: Address.edgeCaseBaseline)
                }
            }

            extension Profile: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testCustomTypeOnlyProperties() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Wrapper {
                let inner: Address
            }
            """,
            expandedSource: """
            struct Wrapper {
                let inner: Address

                static var edgeCases: [Self] {
                    Address.edgeCases.map {
                        Self(inner: $0)
                    }
                }

                static var edgeCaseBaseline: Self {
                    Self(inner: Address.edgeCaseBaseline)
                }
            }

            extension Wrapper: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testOptionalCustomTypeProperty() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Delivery {
                let destination: Address?
            }
            """,
            expandedSource: """
            struct Delivery {
                let destination: Address?

                static var edgeCases: [Self] {
                    [
                        Self(destination: nil),
                    ]
                    + Address.edgeCases.map {
                        Self(destination: $0)
                    }
                }

                static var edgeCaseBaseline: Self {
                    Self(destination: nil)
                }
            }

            extension Delivery: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testArrayOfCustomTypeProperty() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Route {
                let stops: [Address]
            }
            """,
            expandedSource: """
            struct Route {
                let stops: [Address]

                static var edgeCases: [Self] {
                    [
                        Self(stops: []),
                        Self(stops: [Address.edgeCaseBaseline]),
                        Self(stops: Array(repeating: Address.edgeCaseBaseline, count: 1_000)),
                        Self(stops: Address.edgeCases),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(stops: [])
                }
            }

            extension Route: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testUnknownNamedTypeIsAssumedEdgeCaseGeneratable() {
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

                static var edgeCases: [Self] {
                    Date.edgeCases.map {
                        Self(createdAt: $0)
                    }
                }

                static var edgeCaseBaseline: Self {
                    Self(createdAt: Date.edgeCaseBaseline)
                }
            }

            extension Event: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Enums

    func testEnumGeneratesAllCases() {
        assertMacroExpansion(
            """
            @EdgeCases
            enum Direction {
                case north
                case south, east
            }
            """,
            expandedSource: """
            enum Direction {
                case north
                case south, east

                static var edgeCases: [Self] {
                    [
                        Self.north,
                        Self.south,
                        Self.east,
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self.north
                }
            }

            extension Direction: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testEnumVariesAssociatedValues() {
        assertMacroExpansion(
            """
            @EdgeCases
            enum Command {
                case ping
                case retry(attempts: Int8)
                case resize(Int, Int)
            }
            """,
            expandedSource: """
            enum Command {
                case ping
                case retry(attempts: Int8)
                case resize(Int, Int)

                static var edgeCases: [Self] {
                    [
                        Self.ping,
                        Self.retry(attempts: Int8.min),
                        Self.retry(attempts: Int8.max),
                        Self.retry(attempts: 0),
                        Self.retry(attempts: -1),
                        Self.resize(Int.min, 0),
                        Self.resize(Int.max, 0),
                        Self.resize(0, 0),
                        Self.resize(-1, 0),
                        Self.resize(0, Int.min),
                        Self.resize(0, Int.max),
                        Self.resize(0, -1),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self.ping
                }
            }

            extension Command: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testEnumWithCustomAssociatedValue() {
        assertMacroExpansion(
            """
            @EdgeCases
            enum Event {
                case system
                case user(Account)
            }
            """,
            expandedSource: """
            enum Event {
                case system
                case user(Account)

                static var edgeCases: [Self] {
                    [
                        Self.system,
                    ]
                    + Account.edgeCases.map {
                        Self.user($0)
                    }
                }

                static var edgeCaseBaseline: Self {
                    Self.system
                }
            }

            extension Event: EdgeCaseGeneratable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Diagnostics

    func testDiagnosesUnsupportedDeclaration() {
        assertMacroExpansion(
            """
            @EdgeCases
            class Controller {
                var value: Int = 0
            }
            """,
            expandedSource: """
            class Controller {
                var value: Int = 0
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' can only be attached to a struct or an enum",
                    line: 1,
                    column: 1
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testDiagnosesUnsupportedType() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Bad {
                let point: (Int, Int)
            }
            """,
            expandedSource: """
            struct Bad {
                let point: (Int, Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' has no generator for type '(Int, Int)' of stored property 'point' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable')",
                    line: 3,
                    column: 9
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testDiagnosesUnsupportedAssociatedValueType() {
        assertMacroExpansion(
            """
            @EdgeCases
            enum Bad {
                case send(payload: (Int, Int))
            }
            """,
            expandedSource: """
            enum Bad {
                case send(payload: (Int, Int))
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' has no generator for type '(Int, Int)' in associated values of case 'send' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable')",
                    line: 3,
                    column: 15
                )
            ],
            macroSpecs: testMacros
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
            macroSpecs: testMacros
        )
    }

    func testDiagnosesEnumWithoutCases() {
        assertMacroExpansion(
            """
            @EdgeCases
            enum Impossible {
            }
            """,
            expandedSource: """
            enum Impossible {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' requires an enum to declare at least one case",
                    line: 2,
                    column: 6
                )
            ],
            macroSpecs: testMacros
        )
    }
}
#endif
