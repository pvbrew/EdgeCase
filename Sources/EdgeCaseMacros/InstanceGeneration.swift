/// One argument position of an instance constructor that receives generated
/// values: a stored property of a struct, or an associated value of an enum
/// case.
struct ValueSlot {
    /// Argument label, or `nil` for unlabeled enum associated values.
    let label: String?
    let generator: TypeGenerator
}

/// A way of constructing an instance of the annotated type: the memberwise
/// initializer of a struct, or one case of an enum.
struct InstanceConstructor {
    /// The callee, e.g. `Self` or `Self.card`.
    let callee: String
    let slots: [ValueSlot]
    /// Whether a call with no slots still needs parentheses — `Self()` for
    /// structs, but plain `Self.north` for payload-less enum cases.
    let requiresParentheses: Bool

    /// Builds the call expression from one value expression per slot.
    func expression(with arguments: [String]) -> String {
        if slots.isEmpty && !requiresParentheses {
            return callee
        }
        let list = zip(slots, arguments)
            .map { slot, value in slot.label.map { "\($0): \(value)" } ?? value }
            .joined(separator: ", ")
        return "\(callee)(\(list))"
    }

    var baselineExpression: String {
        expression(with: slots.map(\.generator.baseline))
    }
}

enum InstanceGeneration {
    /// Builds one expression per edge case known at expansion time, varying a
    /// single slot at a time while the rest hold their baseline value. Exact
    /// duplicates are dropped.
    static func literalInstances(for constructors: [InstanceConstructor]) -> [String] {
        var instances: [String] = []
        var seen: Set<String> = []
        func append(_ expression: String) {
            if seen.insert(expression).inserted {
                instances.append(expression)
            }
        }

        for constructor in constructors {
            if constructor.slots.isEmpty {
                append(constructor.baselineExpression)
                continue
            }
            for (varyingIndex, slot) in constructor.slots.enumerated() {
                for edgeCase in slot.generator.edgeCases {
                    let arguments = constructor.slots.enumerated().map { index, other in
                        index == varyingIndex ? edgeCase : other.generator.baseline
                    }
                    append(constructor.expression(with: arguments))
                }
            }
        }
        return instances
    }

    /// Builds one `<Type>.edgeCases.map { ... }` clause per slot whose edge
    /// cases are only known at runtime (nested `EdgeCaseGeneratable` types).
    static func dynamicClauses(for constructors: [InstanceConstructor]) -> [String] {
        var clauses: [String] = []
        for constructor in constructors {
            for (varyingIndex, slot) in constructor.slots.enumerated() {
                guard let source = slot.generator.dynamicSource else { continue }
                let arguments = constructor.slots.enumerated().map { index, other in
                    index == varyingIndex ? "$0" : other.generator.baseline
                }
                clauses.append("\(source).map { \(constructor.expression(with: arguments)) }")
            }
        }
        return clauses
    }

    /// Assembles the body of `edgeCases` from the literal instances and the
    /// dynamic clauses concatenated onto them.
    static func body(literals: [String], dynamics: [String]) -> String {
        var components: [String] = []
        if !literals.isEmpty {
            components.append(
                "[\n" + literals.map { "        \($0)," }.joined(separator: "\n") + "\n    ]"
            )
        }
        components.append(contentsOf: dynamics)

        guard var body = components.first else { return "[]" }
        for component in components.dropFirst() {
            body += "\n    + \(component)"
        }
        return body
    }
}
