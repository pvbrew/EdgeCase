import SwiftDiagnostics
import SwiftSyntax

/// Syntactic analysis of an `@EdgeCases`-annotated declaration: the chosen
/// strategy, the ways instances of it can be constructed, plus any
/// diagnostics to report.
///
/// Both the member and the extension expansion run this; only the member
/// expansion reports the diagnostics, so they are not duplicated.
struct EdgeCasesAnalysis {
    struct Failure {
        let node: Syntax
        let message: EdgeCasesDiagnostic
    }

    let strategy: GenerationStrategy
    let constructors: [InstanceConstructor]
    let failures: [Failure]
    let accessModifier: String

    /// Errors abort generation; warnings are reported and generation
    /// proceeds without the offending property.
    var hasErrors: Bool {
        failures.contains { $0.message.severity == .error }
    }

    /// The all-baseline instance. Only meaningful when `hasErrors` is false,
    /// which guarantees at least one constructor.
    var baselineExpression: String {
        constructors[0].baselineExpression
    }

    /// Returns `nil` if the declaration is not a struct or an enum.
    init?(node: AttributeSyntax, declaration: some DeclGroupSyntax) {
        var failures: [Failure] = []
        strategy = Self.strategy(of: node, failures: &failures)

        let analyzed: (constructors: [InstanceConstructor], failures: [Failure])
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            analyzed = Self.analyzeStruct(structDecl)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            analyzed = Self.analyzeEnum(enumDecl)
        } else {
            return nil
        }
        constructors = analyzed.constructors
        self.failures = failures + analyzed.failures
        accessModifier = Self.accessModifier(of: declaration)
    }

    // MARK: Strategy

    private static func strategy(
        of node: AttributeSyntax,
        failures: inout [Failure]
    ) -> GenerationStrategy {
        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self),
              let argument = arguments.first(where: { $0.label?.text == "strategy" })
        else {
            return .oneAtATime
        }
        guard let member = argument.expression.as(MemberAccessExprSyntax.self),
              let strategy = GenerationStrategy(memberName: member.declName.baseName.text)
        else {
            failures.append(Failure(node: Syntax(argument.expression), message: .invalidStrategy))
            return .oneAtATime
        }
        return strategy
    }

    // MARK: Overrides

    private enum OverrideKind {
        case custom(values: [String])
        case exclude
    }

    private struct Override {
        let node: Syntax
        let kind: OverrideKind
    }

    /// Extracts the `@EdgeCase(...)` override of a property declaration, if
    /// any, appending parse failures. Applies to every binding of the
    /// declaration.
    private static func parseOverride(
        of variable: VariableDeclSyntax,
        failures: inout [Failure]
    ) -> Override? {
        var found: Override?
        for element in variable.attributes {
            guard case .attribute(let attribute) = element else { continue }
            let name = attribute.attributeName.as(IdentifierTypeSyntax.self)?.name.text
                ?? attribute.attributeName.as(MemberTypeSyntax.self)?.name.text
            guard name == "EdgeCase" else { continue }
            if found != nil {
                failures.append(
                    Failure(
                        node: Syntax(attribute),
                        message: .duplicateOverride(property: primaryName(of: variable))
                    )
                )
                continue
            }
            found = parse(attribute, failures: &failures)
        }
        return found
    }

    private static func parse(
        _ attribute: AttributeSyntax,
        failures: inout [Failure]
    ) -> Override? {
        guard let arguments = attribute.arguments?.as(LabeledExprListSyntax.self),
              arguments.count == 1,
              let expression = arguments.first?.expression
        else {
            failures.append(Failure(node: Syntax(attribute), message: .invalidOverride))
            return nil
        }

        if let member = expression.as(MemberAccessExprSyntax.self) {
            guard member.declName.baseName.text == "exclude" else {
                failures.append(Failure(node: Syntax(expression), message: .invalidOverride))
                return nil
            }
            return Override(node: Syntax(attribute), kind: .exclude)
        }

        if let call = expression.as(FunctionCallExprSyntax.self),
           let member = call.calledExpression.as(MemberAccessExprSyntax.self),
           member.declName.baseName.text == "custom" {
            guard call.arguments.count == 1,
                  let array = call.arguments.first?.expression.as(ArrayExprSyntax.self)
            else {
                failures.append(
                    Failure(node: Syntax(expression), message: .customOverrideNotArrayLiteral)
                )
                return nil
            }
            var seen: Set<String> = []
            let values = array.elements
                .map { $0.expression.trimmedDescription }
                .filter { seen.insert($0).inserted }
            guard !values.isEmpty else {
                failures.append(Failure(node: Syntax(array), message: .customOverrideEmpty))
                return nil
            }
            return Override(node: Syntax(attribute), kind: .custom(values: values))
        }

        failures.append(Failure(node: Syntax(expression), message: .invalidOverride))
        return nil
    }

    private static func primaryName(of variable: VariableDeclSyntax) -> String {
        variable.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
            ?? "property"
    }

    // MARK: Structs

    private static func analyzeStruct(
        _ structDecl: StructDeclSyntax
    ) -> (constructors: [InstanceConstructor], failures: [Failure]) {
        var slots: [ValueSlot] = []
        var failures: [Failure] = []

        for member in structDecl.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            let override = parseOverride(of: variable, failures: &failures)

            let isExcludedByModifier = variable.modifiers.contains { modifier in
                modifier.name.tokenKind == .keyword(.static) || modifier.name.tokenKind == .keyword(.lazy)
            }
            if isExcludedByModifier {
                if let override {
                    failures.append(
                        Failure(
                            node: override.node,
                            message: .overrideOnNonStoredProperty(property: primaryName(of: variable))
                        )
                    )
                }
                continue
            }

            let isLet = variable.bindingSpecifier.tokenKind == .keyword(.let)
            let bindings = Array(variable.bindings)

            for (index, binding) in bindings.enumerated() {
                let name = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text

                if isComputed(binding) {
                    if let override, let name {
                        failures.append(
                            Failure(node: override.node, message: .overrideOnNonStoredProperty(property: name))
                        )
                    }
                    continue
                }
                // A constant with a fixed value is excluded from the memberwise
                // initializer, so it cannot be varied.
                if isLet && binding.initializer != nil {
                    if let override, let name {
                        failures.append(
                            Failure(node: override.node, message: .overrideOnFixedConstant(property: name))
                        )
                    }
                    continue
                }

                guard let name else {
                    if binding.initializer == nil {
                        failures.append(Failure(node: Syntax(binding), message: .unsupportedPattern))
                    }
                    continue
                }

                let annotation = resolvedType(for: binding, at: index, in: bindings)
                let writtenType = annotation.map(normalizedTypeDescription)

                switch override?.kind {
                case .exclude:
                    // With a default value the memberwise initializer fills the
                    // property in; the generated calls simply omit it.
                    if binding.initializer != nil { continue }
                    guard let annotation else {
                        failures.append(
                            Failure(node: Syntax(binding), message: .missingTypeAnnotation(property: name))
                        )
                        continue
                    }
                    guard let generator = TypeGenerator.generator(for: annotation) else {
                        failures.append(
                            Failure(
                                node: Syntax(binding),
                                message: .excludeNeedsValue(property: name, type: annotation.trimmedDescription)
                            )
                        )
                        continue
                    }
                    slots.append(
                        ValueSlot(
                            label: name,
                            writtenType: writtenType,
                            generator: TypeGenerator(edgeCases: [], baseline: generator.baseline)
                        )
                    )

                case .custom(let values):
                    slots.append(
                        ValueSlot(
                            label: name,
                            writtenType: writtenType,
                            generator: TypeGenerator(edgeCases: values, baseline: values[0])
                        )
                    )

                case nil:
                    guard let annotation else {
                        failures.append(
                            Failure(node: Syntax(binding), message: .missingTypeAnnotation(property: name))
                        )
                        continue
                    }
                    guard let generator = TypeGenerator.generator(for: annotation) else {
                        if binding.initializer != nil {
                            failures.append(
                                Failure(
                                    node: Syntax(binding),
                                    message: .unsupportedTypeUsesDefault(
                                        property: name,
                                        type: annotation.trimmedDescription
                                    )
                                )
                            )
                        } else {
                            failures.append(
                                Failure(
                                    node: Syntax(binding),
                                    message: .unsupportedType(
                                        property: name,
                                        type: annotation.trimmedDescription
                                    )
                                )
                            )
                        }
                        continue
                    }
                    slots.append(
                        ValueSlot(label: name, writtenType: writtenType, generator: deduplicated(generator))
                    )
                }
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

    /// The written type usable inside generic positions of the emitted code:
    /// `Int!` cannot appear in `[Int!]`, so implicitly unwrapped optionals
    /// are rewritten as plain optionals.
    private static func normalizedTypeDescription(_ type: TypeSyntax) -> String {
        if let unwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return unwrapped.wrappedType.trimmedDescription + "?"
        }
        return type.trimmedDescription
    }

    /// Removes textually duplicate edge cases (`Int??` contributes `nil`
    /// twice) so no strategy generates duplicate instances from them.
    private static func deduplicated(_ generator: TypeGenerator) -> TypeGenerator {
        var seen: Set<String> = []
        return TypeGenerator(
            edgeCases: generator.edgeCases.filter { seen.insert($0).inserted },
            baseline: generator.baseline,
            dynamicSource: generator.dynamicSource,
            distinct: generator.distinct
        )
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
                        slots.append(
                            ValueSlot(
                                label: label,
                                writtenType: normalizedTypeDescription(parameter.type),
                                generator: deduplicated(generator)
                            )
                        )
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
