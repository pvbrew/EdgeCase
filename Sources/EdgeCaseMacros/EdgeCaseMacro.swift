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
/// The `strategy:` argument picks how property edge cases combine into
/// instances: `.oneAtATime` (default) varies one property while the others
/// hold a baseline value (`0`, `""`, `false`, `nil`, `[]`), `.minimal` mixes
/// the i-th edge case of every property into instance i (cycling shorter
/// lists), and `.combinatorial` emits the cartesian product, capped at
/// 1,000 instances per constructed case with a warning when the known count
/// exceeds the cap. Exact duplicates are dropped. Edge cases of nested
/// `EdgeCaseGeneratable` types are only known at runtime, so they are
/// spliced in with `map` (or, for the non-default strategies, an
/// immediately-applied closure) over the nested type's `edgeCases`.
///
/// Per-property `@EdgeCase(.custom([...]))` and `@EdgeCase(.exclude)`
/// markers replace or remove a property's contribution.
public struct EdgeCasesMacro {}

extension EdgeCasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let analysis = EdgeCasesAnalysis(node: node, declaration: declaration) else {
            context.diagnose(Diagnostic(node: node, message: EdgeCasesDiagnostic.unsupportedDeclaration))
            return []
        }
        for failure in analysis.failures {
            context.diagnose(Diagnostic(node: failure.node, message: failure.message))
        }
        guard !analysis.hasErrors else { return [] }

        if analysis.strategy == .combinatorial,
           let count = InstanceGeneration.knownCombinatorialCount(for: analysis.constructors),
           count > GenerationStrategy.combinatorialCap {
            context.diagnose(
                Diagnostic(node: node, message: EdgeCasesDiagnostic.combinatorialCapExceeded(count: count))
            )
        }

        let body = InstanceGeneration.body(for: analysis.constructors, strategy: analysis.strategy)
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
              let analysis = EdgeCasesAnalysis(node: node, declaration: declaration),
              !analysis.hasErrors
        else {
            return []
        }
        return [try ExtensionDeclSyntax("extension \(type.trimmed): EdgeCaseGeneratable {}")]
    }
}

/// Implementation of the `@EdgeCase(...)` per-property marker. It expands to
/// nothing — the override it carries is read syntactically by the
/// `@EdgeCases` expansion on the containing type.
public struct EdgeCaseOverrideMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        []
    }
}

@main
struct EdgeCasePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EdgeCasesMacro.self,
        EdgeCaseOverrideMacro.self,
    ]
}
