import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

/// Implementation of the `@EdgeCases` macro, which attaches to a struct
/// and generates a `static var edgeCases: [Self]` populated with
/// boundary/adversarial instances of that type.
///
/// Instances are generated one property at a time: each stored property is
/// run through its type's edge cases while every other property holds a
/// baseline value (`0`, `""`, `false`). Exact duplicates are dropped, so the
/// case count grows linearly with the number of properties.
public struct EdgeCasesMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let structDecl = declaration.as(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(node: node, message: EdgeCasesDiagnostic.notAStruct))
            return []
        }

        guard let properties = storedProperties(of: structDecl, in: context) else {
            return []
        }

        let instances = instanceExpressions(for: properties)
        let body: String
        if instances.isEmpty {
            body = "[]"
        } else {
            body = "[\n" + instances.map { "        \($0)," }.joined(separator: "\n") + "\n    ]"
        }

        let decl: DeclSyntax =
            """
            \(raw: accessModifier(of: structDecl))static var edgeCases: [Self] {
                \(raw: body)
            }
            """
        return [decl]
    }

    // MARK: Stored property discovery

    /// Returns the stored properties that participate in generation, or `nil`
    /// if an error diagnostic was emitted.
    private static func storedProperties(
        of structDecl: StructDeclSyntax,
        in context: some MacroExpansionContext
    ) -> [StoredProperty]? {
        var properties: [StoredProperty] = []
        var hadError = false

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }

            let isExcludedByModifier = variable.modifiers.contains { modifier in
                modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.lazy)
            }
            if isExcludedByModifier { continue }

            let isLet = variable.bindingSpecifier.tokenKind == .keyword(.let)
            let bindings = Array(variable.bindings)

            for (index, binding) in bindings.enumerated() {
                if isComputed(binding) { continue }
                // A constant with a fixed value is excluded from the memberwise
                // initializer, so it cannot be varied.
                if isLet && binding.initializer != nil { continue }

                guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                    if binding.initializer == nil {
                        context.diagnose(
                            Diagnostic(node: Syntax(binding), message: EdgeCasesDiagnostic.unsupportedPattern)
                        )
                        hadError = true
                    }
                    continue
                }
                let name = pattern.identifier.text

                guard let typeName = resolvedTypeName(for: binding, at: index, in: bindings) else {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(binding),
                            message: EdgeCasesDiagnostic.missingTypeAnnotation(property: name)
                        )
                    )
                    hadError = true
                    continue
                }

                guard let generator = PrimitiveGenerator.generator(forTypeNamed: typeName) else {
                    context.diagnose(
                        Diagnostic(
                            node: Syntax(binding),
                            message: EdgeCasesDiagnostic.unsupportedType(property: name, type: typeName)
                        )
                    )
                    hadError = true
                    continue
                }

                properties.append(StoredProperty(name: name, generator: generator))
            }
        }

        return hadError ? nil : properties
    }

    /// Resolves the written type of a binding, following Swift's rule that in
    /// `let x, y: Int` the annotation of a later binding applies to earlier
    /// annotation-less bindings.
    private static func resolvedTypeName(
        for binding: PatternBindingSyntax,
        at index: Int,
        in bindings: [PatternBindingSyntax]
    ) -> String? {
        if let annotation = binding.typeAnnotation {
            return annotation.type.trimmedDescription
        }
        guard binding.initializer == nil else { return nil }
        for later in bindings[(index + 1)...] {
            if let annotation = later.typeAnnotation {
                return annotation.type.trimmedDescription
            }
            if later.initializer != nil { return nil }
        }
        return nil
    }

    /// Whether a binding declares a computed property. Bindings with only
    /// `willSet`/`didSet` observers are still stored.
    private static func isComputed(_ binding: PatternBindingSyntax) -> Bool {
        guard let accessorBlock = binding.accessorBlock else { return false }
        switch accessorBlock.accessors {
        case .getter:
            return true
        case .accessors(let accessorList):
            return accessorList.contains { accessor in
                switch accessor.accessorSpecifier.tokenKind {
                case .keyword(.willSet), .keyword(.didSet):
                    return false
                default:
                    return true
                }
            }
        }
    }

    // MARK: Generation

    /// Builds one `Self(...)` expression per edge case, varying a single
    /// property at a time while the rest hold their baseline value.
    private static func instanceExpressions(for properties: [StoredProperty]) -> [String] {
        var instances: [String] = []
        var seen: Set<String> = []

        for (varyingIndex, property) in properties.enumerated() {
            for edgeCase in property.generator.edgeCases {
                let arguments = properties.enumerated()
                    .map { index, other in
                        "\(other.name): \(index == varyingIndex ? edgeCase : other.generator.baseline)"
                    }
                    .joined(separator: ", ")
                if seen.insert(arguments).inserted {
                    instances.append("Self(\(arguments))")
                }
            }
        }
        return instances
    }

    /// Mirrors the struct's `public`/`package` access level onto the
    /// generated member.
    private static func accessModifier(of structDecl: StructDeclSyntax) -> String {
        for modifier in structDecl.modifiers {
            switch modifier.name.tokenKind {
            case .keyword(.public), .keyword(.package):
                return modifier.name.text + " "
            default:
                break
            }
        }
        return ""
    }
}

@main
struct EdgeCasePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        EdgeCasesMacro.self,
    ]
}
