// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "EdgeCase",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        .library(
            name: "EdgeCase",
            targets: ["EdgeCase"]
        ),
        // Companion products for test targets only: XCTest sugar and
        // swift-testing support. Kept separate from EdgeCase so app targets
        // never link a testing framework.
        .library(
            name: "EdgeCaseXCTest",
            targets: ["EdgeCaseXCTest"]
        ),
        .library(
            name: "EdgeCaseTesting",
            targets: ["EdgeCaseTesting"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0-latest"),
        // Documentation generation for the hosted docs; contributes no code.
        .package(url: "https://github.com/swiftlang/swift-docc-plugin", from: "1.4.0"),
    ],
    targets: [
        // Macro implementation that performs the source transformation.
        .macro(
            name: "EdgeCaseMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // The library clients import: the macro declarations, the protocols,
        // and the bundled Foundation conformances.
        .target(name: "EdgeCase", dependencies: ["EdgeCaseMacros"]),

        // XCTest integration: `XCTAssertNoThrow(forEachEdgeCase:)`. Add to
        // test targets only.
        .target(name: "EdgeCaseXCTest", dependencies: ["EdgeCase"]),

        // swift-testing integration: labeled `@Test(arguments:)` support.
        // Add to test targets only.
        .target(name: "EdgeCaseTesting", dependencies: ["EdgeCase"]),

        // Exercises the macro expansion itself against expected source text.
        .testTarget(
            name: "EdgeCaseTests",
            dependencies: [
                "EdgeCaseMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

        // Compiles and runs the generated code, verifying the expansions
        // type-check and produce the expected values.
        .testTarget(
            name: "EdgeCaseRuntimeTests",
            dependencies: ["EdgeCase"]
        ),

        // Exercises the XCTest sugar, including its failure reporting.
        .testTarget(
            name: "EdgeCaseXCTestTests",
            dependencies: ["EdgeCaseXCTest"]
        ),

        // swift-testing suite driving `@Test(arguments:)` end-to-end with
        // labeled edge cases.
        .testTarget(
            name: "EdgeCaseTestingTests",
            dependencies: ["EdgeCaseTesting"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
