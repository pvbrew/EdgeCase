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
/// extension role the way the compiler does. The `@EdgeCase` marker is
/// registered too, so it is consumed (and stripped) exactly as in a build.
let testMacros: [String: MacroSpec] = [
    "EdgeCases": MacroSpec(
        type: EdgeCasesMacro.self,
        conformances: ["EdgeCaseGeneratable", "EdgeCaseComposable"]
    ),
    "EdgeCase": MacroSpec(type: EdgeCaseOverrideMacro.self),
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(x: Int.min, y: base.y),
                        Self(x: Int.max, y: base.y),
                        Self(x: 0, y: base.y),
                        Self(x: -1, y: base.y),
                        Self(x: base.x, y: Int.min),
                        Self(x: base.x, y: Int.max),
                        Self(x: base.x, y: 0),
                        Self(x: base.x, y: -1),
                    ]
                }
            }

            extension Coordinate: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(value: Int8.min),
                        Self(value: Int8.max),
                        Self(value: 0),
                        Self(value: -1),
                    ]
                }
            }

            extension Sample: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(value: -Double.greatestFiniteMagnitude),
                        Self(value: Double.greatestFiniteMagnitude),
                        Self(value: 0),
                        Self(value: Double.nan),
                        Self(value: Double.infinity),
                    ]
                }
            }

            extension Measurement: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
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
            }

            extension Message: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(isOn: true),
                        Self(isOn: false),
                    ]
                }
            }

            extension Flag: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(id: Int.min, name: base.name, isActive: base.isActive),
                        Self(id: Int.max, name: base.name, isActive: base.isActive),
                        Self(id: 0, name: base.name, isActive: base.isActive),
                        Self(id: -1, name: base.name, isActive: base.isActive),
                        Self(id: base.id, name: "", isActive: base.isActive),
                        Self(id: base.id, name: "a", isActive: base.isActive),
                        Self(id: base.id, name: String(repeating: "a", count: 10_000), isActive: base.isActive),
                        Self(id: base.id, name: " \t\n", isActive: base.isActive),
                        Self(id: base.id, name: "\u{1F9D1}\u{200D}\u{1F680}\u{1F44D}\u{1F3FD}\u{1F1EC}\u{1F1F7}", isActive: base.isActive),
                        Self(id: base.id, name: "\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{05E9}\u{05DC}\u{05D5}\u{05DD}", isActive: base.isActive),
                        Self(id: base.id, name: "a\u{200B}b\u{200C}c\u{200D}d", isActive: base.isActive),
                        Self(id: base.id, name: "Cafe\u{0301}", isActive: base.isActive),
                        Self(id: base.id, name: base.name, isActive: true),
                        Self(id: base.id, name: base.name, isActive: false),
                    ]
                }
            }

            extension User: EdgeCaseGeneratable, EdgeCaseComposable {
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

                public static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(points: Int.min),
                        Self(points: Int.max),
                        Self(points: 0),
                        Self(points: -1),
                    ]
                }
            }

            extension Score: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(retries: Int.min, verbose: base.verbose),
                        Self(retries: Int.max, verbose: base.verbose),
                        Self(retries: 0, verbose: base.verbose),
                        Self(retries: -1, verbose: base.verbose),
                        Self(retries: base.retries, verbose: true),
                        Self(retries: base.retries, verbose: false),
                    ]
                }
            }

            extension Config: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(x: Int.min, y: base.y),
                        Self(x: Int.max, y: base.y),
                        Self(x: 0, y: base.y),
                        Self(x: -1, y: base.y),
                        Self(x: base.x, y: Int.min),
                        Self(x: base.x, y: Int.max),
                        Self(x: base.x, y: 0),
                        Self(x: base.x, y: -1),
                    ]
                }
            }

            extension Point: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(),
                    ]
                }
            }

            extension Empty: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(age: nil, bonus: base.bonus),
                        Self(age: Int.min, bonus: base.bonus),
                        Self(age: Int.max, bonus: base.bonus),
                        Self(age: 0, bonus: base.bonus),
                        Self(age: -1, bonus: base.bonus),
                        Self(age: base.age, bonus: nil),
                        Self(age: base.age, bonus: Int.min),
                        Self(age: base.age, bonus: Int.max),
                        Self(age: base.age, bonus: 0),
                        Self(age: base.age, bonus: -1),
                    ]
                }
            }

            extension Form: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(counts: [], bytes: base.bytes),
                        Self(counts: [0], bytes: base.bytes),
                        Self(counts: Array(repeating: 0, count: 1_000), bytes: base.bytes),
                        Self(counts: [Int.min, Int.max, 0, -1], bytes: base.bytes),
                        Self(counts: base.counts, bytes: []),
                        Self(counts: base.counts, bytes: [0]),
                        Self(counts: base.counts, bytes: Array(repeating: 0, count: 1_000)),
                        Self(counts: base.counts, bytes: [Int8.min, Int8.max, 0, -1]),
                    ]
                }
            }

            extension Basket: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(stock: [:], ids: base.ids, flags: base.flags),
                        Self(stock: Dictionary(uniqueKeysWithValues: zip((0 ..< 1_000).map(String.init), repeatElement(0, count: 1_000))), ids: base.ids, flags: base.flags),
                        Self(stock: base.stock, ids: [], flags: base.flags),
                        Self(stock: base.stock, ids: Set(0 ..< 1_000), flags: base.flags),
                        Self(stock: base.stock, ids: base.ids, flags: []),
                    ]
                }
            }

            extension Catalog: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(attachments: nil),
                        Self(attachments: []),
                        Self(attachments: [0]),
                        Self(attachments: Array(repeating: 0, count: 1_000)),
                        Self(attachments: [Int.min, Int.max, 0, -1]),
                    ]
                }
            }

            extension Draft: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(level: Int.min, address: base.address),
                        Self(level: Int.max, address: base.address),
                        Self(level: 0, address: base.address),
                        Self(level: -1, address: base.address),
                    ]
                    + Address.edgeCases.map {
                        Self(level: base.level, address: $0)
                    }
                }
            }

            extension Profile: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    Address.edgeCases.map {
                        Self(inner: $0)
                    }
                }
            }

            extension Wrapper: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(destination: nil),
                    ]
                    + Address.edgeCases.map {
                        Self(destination: $0)
                    }
                }
            }

            extension Delivery: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(stops: []),
                        Self(stops: [Address.edgeCaseBaseline]),
                        Self(stops: Array(repeating: Address.edgeCaseBaseline, count: 1_000)),
                        Self(stops: Address.edgeCases),
                    ]
                }
            }

            extension Route: EdgeCaseGeneratable, EdgeCaseComposable {
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

                static func edgeCases(varying base: Self) -> [Self] {
                    Date.edgeCases.map {
                        Self(createdAt: $0)
                    }
                }
            }

            extension Event: EdgeCaseGeneratable, EdgeCaseComposable {
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
                    message: "'@EdgeCases' has no generator for type '(Int, Int)' of stored property 'point' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable', or attach '@EdgeCase(.custom([...]))')",
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

    // MARK: - Custom overrides (v0.3)

    func testCustomOverrideReplacesGeneratedCases() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Patient {
                @EdgeCase(.custom([0, 1, 149, 150]))
                let age: Int
                let isInsured: Bool
            }
            """,
            expandedSource: """
            struct Patient {
                let age: Int
                let isInsured: Bool

                static var edgeCases: [Self] {
                    [
                        Self(age: 0, isInsured: false),
                        Self(age: 1, isInsured: false),
                        Self(age: 149, isInsured: false),
                        Self(age: 150, isInsured: false),
                        Self(age: 0, isInsured: true),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(age: 0, isInsured: false)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(age: 0, isInsured: base.isInsured),
                        Self(age: 1, isInsured: base.isInsured),
                        Self(age: 149, isInsured: base.isInsured),
                        Self(age: 150, isInsured: base.isInsured),
                        Self(age: base.age, isInsured: true),
                        Self(age: base.age, isInsured: false),
                    ]
                }
            }

            extension Patient: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testCustomOverrideOnUnsupportedTypeSuppliesTheGenerator() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Canvas {
                @EdgeCase(.custom([(0, 0), (-1, 1)]))
                let origin: (Int, Int)
            }
            """,
            expandedSource: """
            struct Canvas {
                let origin: (Int, Int)

                static var edgeCases: [Self] {
                    [
                        Self(origin: (0, 0)),
                        Self(origin: (-1, 1)),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(origin: (0, 0))
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(origin: (0, 0)),
                        Self(origin: (-1, 1)),
                    ]
                }
            }

            extension Canvas: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testCustomOverrideOnCustomTypeReplacesRecursion() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Delivery {
                @EdgeCase(.custom([Address.headquarters]))
                let destination: Address
            }
            """,
            expandedSource: """
            struct Delivery {
                let destination: Address

                static var edgeCases: [Self] {
                    [
                        Self(destination: Address.headquarters),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(destination: Address.headquarters)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(destination: Address.headquarters),
                    ]
                }
            }

            extension Delivery: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Exclusion (v0.3)

    func testExcludeWithDefaultValueOmitsTheProperty() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Screen {
                let title: Bool
                @EdgeCase(.exclude)
                var theme: String = "dark"
            }
            """,
            expandedSource: """
            struct Screen {
                let title: Bool
                var theme: String = "dark"

                static var edgeCases: [Self] {
                    [
                        Self(title: true),
                        Self(title: false),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(title: false)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(title: true, theme: base.theme),
                        Self(title: false, theme: base.theme),
                    ]
                }
            }

            extension Screen: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testExcludeWithoutDefaultHoldsTheBaseline() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Report {
                let pages: Int
                @EdgeCase(.exclude)
                let watermark: String
            }
            """,
            expandedSource: """
            struct Report {
                let pages: Int
                let watermark: String

                static var edgeCases: [Self] {
                    [
                        Self(pages: Int.min, watermark: ""),
                        Self(pages: Int.max, watermark: ""),
                        Self(pages: 0, watermark: ""),
                        Self(pages: -1, watermark: ""),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(pages: 0, watermark: "")
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(pages: Int.min, watermark: base.watermark),
                        Self(pages: Int.max, watermark: base.watermark),
                        Self(pages: 0, watermark: base.watermark),
                        Self(pages: -1, watermark: base.watermark),
                    ]
                }
            }

            extension Report: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testExcludeOnCustomTypeSkipsTheRuntimeClause() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Wrapper {
                let flag: Bool
                @EdgeCase(.exclude)
                let inner: Address
            }
            """,
            expandedSource: """
            struct Wrapper {
                let flag: Bool
                let inner: Address

                static var edgeCases: [Self] {
                    [
                        Self(flag: true, inner: Address.edgeCaseBaseline),
                        Self(flag: false, inner: Address.edgeCaseBaseline),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(flag: false, inner: Address.edgeCaseBaseline)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(flag: true, inner: base.inner),
                        Self(flag: false, inner: base.inner),
                    ]
                }
            }

            extension Wrapper: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Minimal strategy (v0.3)

    func testMinimalStrategyMixesEdgeCasesCyclingShorterLists() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .minimal)
            struct Login {
                let attempts: Int
                let remember: Bool
            }
            """,
            expandedSource: """
            struct Login {
                let attempts: Int
                let remember: Bool

                static var edgeCases: [Self] {
                    [
                        Self(attempts: Int.min, remember: true),
                        Self(attempts: Int.max, remember: false),
                        Self(attempts: 0, remember: true),
                        Self(attempts: -1, remember: false),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(attempts: 0, remember: false)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(attempts: Int.min, remember: base.remember),
                        Self(attempts: Int.max, remember: base.remember),
                        Self(attempts: 0, remember: base.remember),
                        Self(attempts: -1, remember: base.remember),
                        Self(attempts: base.attempts, remember: true),
                        Self(attempts: base.attempts, remember: false),
                    ]
                }
            }

            extension Login: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testMinimalStrategyWithNestedTypeEmitsRuntimeForm() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .minimal)
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
                    { () -> [Self] in
                        let column0: [Int] = [Int.min, Int.max, 0, -1]
                        let column1: [Address] = Address.edgeCases
                        let count = max(column0.count, column1.count)
                        return (0 ..< count).map { index in
                            Self(level: column0[index % column0.count], address: column1[index % column1.count])
                        }
                    }()
                }

                static var edgeCaseBaseline: Self {
                    Self(level: 0, address: Address.edgeCaseBaseline)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(level: Int.min, address: base.address),
                        Self(level: Int.max, address: base.address),
                        Self(level: 0, address: base.address),
                        Self(level: -1, address: base.address),
                    ]
                    + Address.edgeCases.map {
                        Self(level: base.level, address: $0)
                    }
                }
            }

            extension Profile: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testMinimalStrategyWithOptionalCustomTypeCoercesTheColumn() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .minimal)
            struct Delivery {
                let destination: Address?
            }
            """,
            expandedSource: """
            struct Delivery {
                let destination: Address?

                static var edgeCases: [Self] {
                    { () -> [Self] in
                        let column0: [Address?] = [nil] + Address.edgeCases.map {
                            $0 as Address?
                        }
                        let count = column0.count
                        return (0 ..< count).map { index in
                            Self(destination: column0[index % column0.count])
                        }
                    }()
                }

                static var edgeCaseBaseline: Self {
                    Self(destination: nil)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(destination: nil),
                    ]
                    + Address.edgeCases.map {
                        Self(destination: $0)
                    }
                }
            }

            extension Delivery: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testMinimalStrategyOnEnumKeepsEveryCase() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .minimal)
            enum Command {
                case ping
                case resize(Int, Int)
            }
            """,
            expandedSource: """
            enum Command {
                case ping
                case resize(Int, Int)

                static var edgeCases: [Self] {
                    [
                        Self.ping,
                        Self.resize(Int.min, Int.min),
                        Self.resize(Int.max, Int.max),
                        Self.resize(0, 0),
                        Self.resize(-1, -1),
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

    // MARK: - Combinatorial strategy (v0.3)

    func testCombinatorialStrategyEmitsTheCartesianProduct() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .combinatorial)
            struct Toggle {
                let count: Int8
                let isOn: Bool
            }
            """,
            expandedSource: """
            struct Toggle {
                let count: Int8
                let isOn: Bool

                static var edgeCases: [Self] {
                    [
                        Self(count: Int8.min, isOn: true),
                        Self(count: Int8.min, isOn: false),
                        Self(count: Int8.max, isOn: true),
                        Self(count: Int8.max, isOn: false),
                        Self(count: 0, isOn: true),
                        Self(count: 0, isOn: false),
                        Self(count: -1, isOn: true),
                        Self(count: -1, isOn: false),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(count: 0, isOn: false)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(count: Int8.min, isOn: base.isOn),
                        Self(count: Int8.max, isOn: base.isOn),
                        Self(count: 0, isOn: base.isOn),
                        Self(count: -1, isOn: base.isOn),
                        Self(count: base.count, isOn: true),
                        Self(count: base.count, isOn: false),
                    ]
                }
            }

            extension Toggle: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testCombinatorialStrategyWithNestedTypeEmitsCappedLoop() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .combinatorial)
            struct Shipment {
                let priority: Bool
                let destination: Address
            }
            """,
            expandedSource: """
            struct Shipment {
                let priority: Bool
                let destination: Address

                static var edgeCases: [Self] {
                    { () -> [Self] in
                        let column0: [Bool] = [true, false]
                        let column1: [Address] = Address.edgeCases
                        var instances: [Self] = []
                        loop: for value0 in column0 {
                            for value1 in column1 {
                                if instances.count == 1_000 {
                                    break loop
                                }
                                instances.append(Self(priority: value0, destination: value1))
                            }
                        }
                        return instances
                    }()
                }

                static var edgeCaseBaseline: Self {
                    Self(priority: false, destination: Address.edgeCaseBaseline)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(priority: true, destination: base.destination),
                        Self(priority: false, destination: base.destination),
                    ]
                    + Address.edgeCases.map {
                        Self(priority: base.priority, destination: $0)
                    }
                }
            }

            extension Shipment: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    func testCombinatorialStrategyOverCapWarnsAndCaps() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .combinatorial)
            struct Grid {
                @EdgeCase(.custom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
                let x: Int
                @EdgeCase(.custom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
                let y: Int
                @EdgeCase(.custom([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]))
                let z: Int
            }
            """,
            expandedSource: """
            struct Grid {
                let x: Int
                let y: Int
                let z: Int

                static var edgeCases: [Self] {
                    { () -> [Self] in
                        let column0: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
                        let column1: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
                        let column2: [Int] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]
                        var instances: [Self] = []
                        loop: for value0 in column0 {
                            for value1 in column1 {
                                for value2 in column2 {
                                    if instances.count == 1_000 {
                                        break loop
                                    }
                                    instances.append(Self(x: value0, y: value1, z: value2))
                                }
                            }
                        }
                        return instances
                    }()
                }

                static var edgeCaseBaseline: Self {
                    Self(x: 1, y: 1, z: 1)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(x: 1, y: base.y, z: base.z),
                        Self(x: 2, y: base.y, z: base.z),
                        Self(x: 3, y: base.y, z: base.z),
                        Self(x: 4, y: base.y, z: base.z),
                        Self(x: 5, y: base.y, z: base.z),
                        Self(x: 6, y: base.y, z: base.z),
                        Self(x: 7, y: base.y, z: base.z),
                        Self(x: 8, y: base.y, z: base.z),
                        Self(x: 9, y: base.y, z: base.z),
                        Self(x: 10, y: base.y, z: base.z),
                        Self(x: 11, y: base.y, z: base.z),
                        Self(x: base.x, y: 1, z: base.z),
                        Self(x: base.x, y: 2, z: base.z),
                        Self(x: base.x, y: 3, z: base.z),
                        Self(x: base.x, y: 4, z: base.z),
                        Self(x: base.x, y: 5, z: base.z),
                        Self(x: base.x, y: 6, z: base.z),
                        Self(x: base.x, y: 7, z: base.z),
                        Self(x: base.x, y: 8, z: base.z),
                        Self(x: base.x, y: 9, z: base.z),
                        Self(x: base.x, y: 10, z: base.z),
                        Self(x: base.x, y: 11, z: base.z),
                        Self(x: base.x, y: base.y, z: 1),
                        Self(x: base.x, y: base.y, z: 2),
                        Self(x: base.x, y: base.y, z: 3),
                        Self(x: base.x, y: base.y, z: 4),
                        Self(x: base.x, y: base.y, z: 5),
                        Self(x: base.x, y: base.y, z: 6),
                        Self(x: base.x, y: base.y, z: 7),
                        Self(x: base.x, y: base.y, z: 8),
                        Self(x: base.x, y: base.y, z: 9),
                        Self(x: base.x, y: base.y, z: 10),
                        Self(x: base.x, y: base.y, z: 11),
                    ]
                }
            }

            extension Grid: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'.combinatorial' would generate 1331 instances; generation is capped at 1_000 (consider '.minimal', '.oneAtATime', or '@EdgeCase(.exclude)' on noisy properties)",
                    line: 1,
                    column: 1,
                    severity: .warning
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testCombinatorialStrategyOnEnumMixesLiteralAndRuntimeCases() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .combinatorial)
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
                    + { () -> [Self] in
                        let column0: [Account] = Account.edgeCases
                        var instances: [Self] = []
                        loop: for value0 in column0 {
                            if instances.count == 1_000 {
                                break loop
                            }
                            instances.append(Self.user(value0))
                        }
                        return instances
                    }()
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

    func testExplicitOneAtATimeStrategyMatchesTheDefault() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .oneAtATime)
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(isOn: true),
                        Self(isOn: false),
                    ]
                }
            }

            extension Flag: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    // MARK: - Diagnostics (v0.3)

    func testDiagnosesInvalidStrategy() {
        assertMacroExpansion(
            """
            @EdgeCases(strategy: .fancy)
            struct Broken {
                let value: Int
            }
            """,
            expandedSource: """
            struct Broken {
                let value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'strategy' must be written as '.oneAtATime', '.minimal', or '.combinatorial'",
                    line: 1,
                    column: 22
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testDiagnosesCustomOverrideWithoutArrayLiteral() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Broken {
                @EdgeCase(.custom(someValues))
                let value: Int
            }
            """,
            expandedSource: """
            struct Broken {
                let value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'.custom' requires its values written as an array literal, e.g. '.custom([0, 150])'",
                    line: 3,
                    column: 15
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testDiagnosesEmptyCustomOverride() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Broken {
                @EdgeCase(.custom([]))
                let value: Int
            }
            """,
            expandedSource: """
            struct Broken {
                let value: Int
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'.custom' needs at least one value; the first value doubles as the property's baseline",
                    line: 3,
                    column: 23
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testDiagnosesExcludeOnUnsupportedTypeWithoutDefault() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Broken {
                @EdgeCase(.exclude)
                let point: (Int, Int)
            }
            """,
            expandedSource: """
            struct Broken {
                let point: (Int, Int)
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCase(.exclude)' on 'point' needs a default value, because '(Int, Int)' has no built-in baseline to hold the property at",
                    line: 4,
                    column: 9
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testWarnsWhenOverridingAFixedConstant() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Config {
                @EdgeCase(.custom([1, 2]))
                let retries: Int = 3
                let isOn: Bool
            }
            """,
            expandedSource: """
            struct Config {
                let retries: Int = 3
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

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(isOn: true),
                        Self(isOn: false),
                    ]
                }
            }

            extension Config: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCase' has no effect on 'retries': constants with a default value always keep their fixed value",
                    line: 3,
                    column: 5,
                    severity: .warning
                )
            ],
            macroSpecs: testMacros
        )
    }

    func testWarnsWhenUnsupportedTypeFallsBackToItsDefault() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Layout {
                let isOn: Bool
                var origin: (Int, Int) = (0, 0)
            }
            """,
            expandedSource: """
            struct Layout {
                let isOn: Bool
                var origin: (Int, Int) = (0, 0)

                static var edgeCases: [Self] {
                    [
                        Self(isOn: true),
                        Self(isOn: false),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(isOn: false)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(isOn: true, origin: base.origin),
                        Self(isOn: false, origin: base.origin),
                    ]
                }
            }

            extension Layout: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@EdgeCases' has no generator for type '(Int, Int)'; 'origin' keeps its default value in every generated instance (attach '@EdgeCase(.custom([...]))' to vary it, or '@EdgeCase(.exclude)' to silence this warning)",
                    line: 4,
                    column: 9,
                    severity: .warning
                )
            ],
            macroSpecs: testMacros
        )
    }

    // MARK: - Fixture composition (v0.4)

    /// The composition contract in one place: custom overrides vary within
    /// their domain, excluded properties pass the base value through instead
    /// of reapplying their default, and nested types splice their runtime
    /// cases around the base — every non-varied position reads from `base`.
    func testVaryingMemberComposesOverridesExclusionsAndNestedTypes() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Booking {
                @EdgeCase(.custom([0, 150]))
                let age: Int
                @EdgeCase(.exclude)
                var channel: String = "web"
                let owner: Owner
            }
            """,
            expandedSource: """
            struct Booking {
                let age: Int
                var channel: String = "web"
                let owner: Owner

                static var edgeCases: [Self] {
                    [
                        Self(age: 0, owner: Owner.edgeCaseBaseline),
                        Self(age: 150, owner: Owner.edgeCaseBaseline),
                    ]
                    + Owner.edgeCases.map {
                        Self(age: 0, owner: $0)
                    }
                }

                static var edgeCaseBaseline: Self {
                    Self(age: 0, owner: Owner.edgeCaseBaseline)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(age: 0, channel: base.channel, owner: base.owner),
                        Self(age: 150, channel: base.channel, owner: base.owner),
                    ]
                    + Owner.edgeCases.map {
                        Self(age: base.age, channel: base.channel, owner: $0)
                    }
                }
            }

            extension Booking: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    /// In modules with main-actor default isolation an unannotated
    /// conformance is inferred main-actor-isolated even on a nonisolated
    /// type, which would make `edgeCases` unusable from nonisolated test
    /// code — so a `nonisolated` modifier on the type is mirrored onto the
    /// generated conformances.
    func testNonisolatedTypeGetsNonisolatedConformances() {
        assertMacroExpansion(
            """
            @EdgeCases
            nonisolated struct Beacon {
                let strength: Int
            }
            """,
            expandedSource: """
            nonisolated struct Beacon {
                let strength: Int

                static var edgeCases: [Self] {
                    [
                        Self(strength: Int.min),
                        Self(strength: Int.max),
                        Self(strength: 0),
                        Self(strength: -1),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self(strength: 0)
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(strength: Int.min),
                        Self(strength: Int.max),
                        Self(strength: 0),
                        Self(strength: -1),
                    ]
                }
            }

            extension Beacon: nonisolated EdgeCaseGeneratable, nonisolated EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }

    /// A struct with nothing to vary still composes: the single instance is
    /// the base reconstruction, not an empty array (mirroring the
    /// baseline-only instance `edgeCases` generates).
    func testVaryingMemberWithNothingToVaryReturnsTheBase() {
        assertMacroExpansion(
            """
            @EdgeCases
            struct Pinned {
                @EdgeCase(.exclude)
                var retries: Int = 3
            }
            """,
            expandedSource: """
            struct Pinned {
                var retries: Int = 3

                static var edgeCases: [Self] {
                    [
                        Self(),
                    ]
                }

                static var edgeCaseBaseline: Self {
                    Self()
                }

                static func edgeCases(varying base: Self) -> [Self] {
                    [
                        Self(retries: base.retries),
                    ]
                }
            }

            extension Pinned: EdgeCaseGeneratable, EdgeCaseComposable {
            }
            """,
            macroSpecs: testMacros
        )
    }
}
#endif
