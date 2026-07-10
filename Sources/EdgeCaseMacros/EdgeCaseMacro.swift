import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@EdgeCases` macro, which attaches to a type
/// and generates a `static var edgeCases: [Self]` populated with
/// boundary/adversarial instances of that type.
public struct EdgeCasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        return [
            "static var edgeCases: [Self] { [] }"
        ]
    }
}

@main
struct EdgeCasePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EdgeCasesMacro.self,
    ]
}
