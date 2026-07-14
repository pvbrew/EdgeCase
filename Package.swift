// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "EdgeCase",
    platforms: [.iOS(.v17), .macOS(.v10_15)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "EdgeCase",
            targets: ["EdgeCase"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.0-latest"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "EdgeCaseMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(name: "EdgeCase", dependencies: ["EdgeCaseMacros"]),

        // A test target used to develop the macro implementation.
        .testTarget(
            name: "EdgeCaseTests",
            dependencies: [
                "EdgeCaseMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),

        // A test target that compiles and runs the generated code, verifying
        // the expansions type-check and produce the expected values.
        .testTarget(
            name: "EdgeCaseRuntimeTests",
            dependencies: ["EdgeCase"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
