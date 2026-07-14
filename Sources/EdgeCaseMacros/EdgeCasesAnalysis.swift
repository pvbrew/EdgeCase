import SwiftSyntax

/// Syntactic analysis of an `@EdgeCases`-annotated declaration: the ways
/// instances of it can be constructed, plus any failures to diagnose.
///
/// Both the member and the extension expansion run this; only the member
/// expansion reports the failures, so diagnostics are not duplicated.
struct EdgeCasesAnalysis {
    struct Failure {
        let node: Syntax
        let message: EdgeCasesDiagnostic
    }

    let constructors: [InstanceConstructor]
    let failures: [Failure]
    let accessModifier: String

    /// The all-baseline instance. Only meaningful when `failures` is empty,
    /// which guarantees at least one constructor.
    var baselineExpression: String {
        constructors[0].baselineExpression
    }

    /// Returns `nil` if the declaration is not a struct or an enum.
    init?(_ declaration: some DeclGroupSyntax) {
        let analyzed: (constructors: [InstanceConstructor], failures: [Failure])
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            analyzed = Self.analyzeStruct(structDecl)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            analyzed = Self.analyzeEnum(enumDecl)
        } else {
            return nil
        }
        constructors = analyzed.constructors
        failures = analyzed.failures
        accessModifier = Self.accessModifier(of: declaration)
    }

    // MARK: Structs

    private static func analyzeStruct(
        _ structDecl: StructDeclSyntax
    ) -> (constructors: [InstanceConstructor], failures: [Failure]) {
        var slots: [ValueSlot] = []
        var failures: [Failure] = []

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
                        failures.append(Failure(node: Syntax(binding), message: .unsupportedPattern))
                    }
                    continue
                }
                let name = pattern.identifier.text

                guard let type = resolvedType(for: binding, at: index, in: bindings) else {
                    failures.append(
                        Failure(node: Syntax(binding), message: .missingTypeAnnotation(property: name))
                    )
                    continue
                }

                guard let generator = TypeGenerator.generator(for: type) else {
                    failures.append(
                        Failure(
                            node: Syntax(binding),
                            message: .unsupportedType(property: name, type: type.trimmedDescription)
                        )
                    )
                    continue
                }

                slots.append(ValueSlot(label: name, generator: generator))
            }
        }

        let constructor = InstanceConstructor(callee: "Self", slots: slots, requiresParentheses: true)
        return ([constructor], failures)
    }

    /// Resolves the written type of a binding, following Swift's rule that in
    /// `let x, y: Int` the annotation of a later binding applies to earlier
    /// annotation-less bindings.
    private static func resolvedType(
        for binding: PatternBindingSyntax,
        at index: Int,
        in bindings: [PatternBindingSyntax]
    ) -> TypeSyntax? {
        if let annotation = binding.typeAnnotation {
            return annotation.type
        }
        guard binding.initializer == nil else { return nil }
        for later in bindings[(index + 1)...] {
            if let annotation = later.typeAnnotation {
                return annotation.type
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

    // MARK: Enums

    private static func analyzeEnum(
        _ enumDecl: EnumDeclSyntax
    ) -> (constructors: [InstanceConstructor], failures: [Failure]) {
        var constructors: [InstanceConstructor] = []
        var failures: [Failure] = []

        for member in enumDecl.memberBlock.members {
            guard let caseDecl = member.decl.as(EnumCaseDeclSyntax.self) else { continue }
            for element in caseDecl.elements {
                let caseName = element.name.text
                var slots: [ValueSlot] = []

                if let parameters = element.parameterClause?.parameters {
                    for parameter in parameters {
                        guard let generator = TypeGenerator.generator(for: parameter.type) else {
                            failures.append(
                                Failure(
                                    node: Syntax(parameter),
                                    message: .unsupportedAssociatedValueType(
                                        enumCase: caseName,
                                        type: parameter.type.trimmedDescription
                                    )
                                )
                            )
                            continue
                        }
                        let label: String? =
                            if let firstName = parameter.firstName, firstName.tokenKind != .wildcard {
                                firstName.text
                            } else {
                                nil
                            }
                        slots.append(ValueSlot(label: label, generator: generator))
                    }
                }

                constructors.append(
                    InstanceConstructor(
                        callee: "Self.\(caseName)",
                        slots: slots,
                        requiresParentheses: element.parameterClause != nil
                    )
                )
            }
        }

        if constructors.isEmpty {
            failures.append(Failure(node: Syntax(enumDecl.name), message: .enumWithoutCases))
        }
        return (constructors, failures)
    }

    // MARK: Shared

    /// Mirrors the declaration's `public`/`package` access level onto the
    /// generated members.
    private static func accessModifier(of declaration: some DeclGroupSyntax) -> String {
        for modifier in declaration.modifiers {
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
