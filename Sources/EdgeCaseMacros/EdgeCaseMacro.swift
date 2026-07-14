import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@EdgeCases` macro, which attaches to a struct or an
/// enum and generates a `static var edgeCases: [Self]` populated with
/// boundary/adversarial instances of that type, a
/// `static var edgeCaseBaseline: Self`, and an `EdgeCaseGeneratable`
/// conformance so annotated types can nest inside each other.
///
/// Instances are generated one value at a time: each stored property (or
/// enum associated value) is run through its type's edge cases while every
/// other one holds a baseline value (`0`, `""`, `false`, `nil`, `[]`). Exact
/// duplicates are dropped, so the case count grows linearly. Edge cases of
/// nested `EdgeCaseGeneratable` types are only known at runtime, so they are
/// spliced in with `map` over the nested type's `edgeCases`.
public struct EdgeCasesMacro {}

extension EdgeCasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let analysis = EdgeCasesAnalysis(declaration) else {
            context.diagnose(Diagnostic(node: node, message: EdgeCasesDiagnostic.unsupportedDeclaration))
            return []
        }
        guard analysis.failures.isEmpty else {
            for failure in analysis.failures {
                context.diagnose(Diagnostic(node: failure.node, message: failure.message))
            }
            return []
        }

        let literals = InstanceGeneration.literalInstances(for: analysis.constructors)
        let dynamics = InstanceGeneration.dynamicClauses(for: analysis.constructors)
        let body = InstanceGeneration.body(literals: literals, dynamics: dynamics)
        let access = analysis.accessModifier

        let edgeCases: DeclSyntax =
            """
            \(raw: access)static var edgeCases: [Self] {
                \(raw: body)
            }
            """
        let baseline: DeclSyntax =
            """
            \(raw: access)static var edgeCaseBaseline: Self {
                \(raw: analysis.baselineExpression)
            }
            """
        return [edgeCases, baseline]
    }
}

extension EdgeCasesMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        // `protocols` is empty when the conformance is already declared.
        // Failures are diagnosed by the member expansion; here an invalid
        // declaration just gets no conformance.
        guard !protocols.isEmpty,
              let analysis = EdgeCasesAnalysis(declaration),
              analysis.failures.isEmpty
        else {
            return []
        }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): EdgeCaseGeneratable {}")]
    }
}

@main
struct EdgeCasePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EdgeCasesMacro.self,
    ]
}
