// The Swift Programming Language
// https://docs.swift.org/swift-book

/// Attaches to a type and generates a `static var edgeCases: [Self]`
/// containing boundary/adversarial instances of that type.
@attached(member, names: named(edgeCases))
public macro EdgeCases() = #externalMacro(module: "EdgeCaseMacros", type: "EdgeCasesMacro")
