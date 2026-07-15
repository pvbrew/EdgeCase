/// Macro-side mirror of the public `EdgeCaseStrategy`, parsed from the
/// `strategy:` argument of the `@EdgeCases` attribute.
enum GenerationStrategy {
    case oneAtATime
    case minimal
    case combinatorial

    /// Hard limit on the instances one constructor may generate under
    /// `.combinatorial`, enforced in the emitted code and surfaced as a
    /// compile-time warning when the known case count exceeds it.
    static let combinatorialCap = 1_000
    static let combinatorialCapSource = "1_000"

    init?(memberName: String) {
        switch memberName {
        case "oneAtATime": self = .oneAtATime
        case "minimal": self = .minimal
        case "combinatorial": self = .combinatorial
        default: return nil
        }
    }
}

/// One argument position of an instance constructor that receives generated
/// values: a stored property of a struct, or an associated value of an enum
/// case.
struct ValueSlot {
    /// Argument label, or `nil` for unlabeled enum associated values.
    let label: String?
    /// The type as written (implicitly unwrapped optionals rewritten as plain
    /// optionals), used to annotate column locals in the runtime generation
    /// forms. `nil` when the declaration has no annotation, which a `.custom`
    /// override permits.
    let writtenType: String?
    let generator: TypeGenerator

    /// Source expression of an array holding every value this slot runs
    /// through, or `nil` for fixed slots that always hold their baseline
    /// (`@EdgeCase(.exclude)` without a default value).
    var columnExpression: String? {
        let literals = generator.edgeCases
        guard let source = generator.dynamicSource else {
            return literals.isEmpty ? nil : "[\(literals.joined(separator: ", "))]"
        }
        guard !literals.isEmpty else { return source }
        // Optional wrapping a custom type: coerce the runtime elements up to
        // the written optional type so the two halves concatenate.
        let element = writtenType.map { "$0 as \($0)" } ?? "$0"
        return "[\(literals.joined(separator: ", "))] + \(source).map { \(element) }"
    }
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

    /// Indices of the slots that actually vary (have a column of values).
    var variedSlotIndices: [Int] {
        slots.indices.filter { slots[$0].columnExpression != nil }
    }

    /// Whether every varied slot's values are known at expansion time.
    var isFullyLiteral: Bool {
        slots.allSatisfy { $0.generator.dynamicSource == nil }
    }

    /// The instance count the constructor produces under `.combinatorial`,
    /// or `nil` when a slot's cases are only known at runtime. Saturates
    /// instead of overflowing.
    var knownCombinatorialCount: Int? {
        guard isFullyLiteral else { return nil }
        var product = 1
        for index in variedSlotIndices {
            let (result, overflow) = product.multipliedReportingOverflow(
                by: slots[index].generator.edgeCases.count
            )
            product = overflow ? Int.max : result
        }
        return product
    }
}

enum InstanceGeneration {
    // MARK: Entry points

    /// Assembles the body of `edgeCases` for the given strategy: a literal
    /// array of the instances known at expansion time, concatenated with one
    /// runtime clause per part that depends on a nested type's `edgeCases`.
    static func body(for constructors: [InstanceConstructor], strategy: GenerationStrategy) -> String {
        var literals: [String] = []
        var runtimeClauses: [String] = []

        switch strategy {
        case .oneAtATime:
            literals = oneAtATimeRows(for: constructors)
            runtimeClauses = oneAtATimeDynamicClauses(for: constructors)
        case .minimal:
            for constructor in constructors {
                if let rows = minimalLiteralRows(for: constructor) {
                    literals.append(contentsOf: rows)
                } else {
                    runtimeClauses.append(runtimeClause(for: constructor, strategy: .minimal))
                }
            }
            literals = deduplicated(literals)
        case .combinatorial:
            for constructor in constructors {
                if let rows = combinatorialLiteralRows(for: constructor) {
                    literals.append(contentsOf: rows)
                } else {
                    runtimeClauses.append(runtimeClause(for: constructor, strategy: .combinatorial))
                }
            }
            literals = deduplicated(literals)
        }

        return assemble(literals: literals, runtimeClauses: runtimeClauses)
    }

    /// Assembles the body of `edgeCases(varying:)`: one property at a time
    /// takes its edge cases while the rest hold `base.<property>`. Always
    /// one-at-a-time regardless of the declared strategy — keeping the rest
    /// of the instance at `base` is the point of composing with a fixture.
    ///
    /// A struct with nothing to vary (every property excluded or fixed)
    /// yields the base reconstruction as its only instance, mirroring the
    /// baseline-only instance `edgeCases` generates.
    static func varyingBody(for constructor: InstanceConstructor) -> String {
        var literals = oneAtATimeRows(for: [constructor])
        let runtimeClauses = oneAtATimeDynamicClauses(for: [constructor])
        if literals.isEmpty && runtimeClauses.isEmpty {
            literals = [constructor.baselineExpression]
        }
        return assemble(literals: literals, runtimeClauses: runtimeClauses)
    }

    /// The `.combinatorial` case count when every slot is literal, or `nil`
    /// when any constructor depends on runtime values. Drives the cap warning.
    static func knownCombinatorialCount(for constructors: [InstanceConstructor]) -> Int? {
        var total = 0
        for constructor in constructors {
            guard let count = constructor.knownCombinatorialCount else { return nil }
            let (sum, overflow) = total.addingReportingOverflow(count)
            total = overflow ? Int.max : sum
        }
        return total
    }

    // MARK: One at a time

    /// One expression per edge case known at expansion time, varying a single
    /// slot while the rest hold their baseline value.
    private static func oneAtATimeRows(for constructors: [InstanceConstructor]) -> [String] {
        var rows: [String] = []
        for constructor in constructors {
            if constructor.slots.isEmpty {
                rows.append(constructor.baselineExpression)
                continue
            }
            for (varyingIndex, slot) in constructor.slots.enumerated() {
                for edgeCase in slot.generator.edgeCases {
                    let arguments = constructor.slots.enumerated().map { index, other in
                        index == varyingIndex ? edgeCase : other.generator.baseline
                    }
                    rows.append(constructor.expression(with: arguments))
                }
            }
        }
        return deduplicated(rows)
    }

    /// One `<Type>.edgeCases.map { ... }` clause per slot whose edge cases
    /// are only known at runtime (nested `EdgeCaseGeneratable` types).
    private static func oneAtATimeDynamicClauses(for constructors: [InstanceConstructor]) -> [String] {
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

    // MARK: Minimal

    /// Rows mixing the i-th edge case of every varied slot, cycling shorter
    /// case lists — or `nil` when a slot's cases are only known at runtime.
    private static func minimalLiteralRows(for constructor: InstanceConstructor) -> [String]? {
        guard constructor.isFullyLiteral else { return nil }
        let varied = constructor.variedSlotIndices
        guard let count = varied.map({ constructor.slots[$0].generator.edgeCases.count }).max() else {
            return [constructor.baselineExpression]
        }
        return (0 ..< count).map { row in
            let arguments = constructor.slots.map { slot -> String in
                let cases = slot.generator.edgeCases
                return cases.isEmpty ? slot.generator.baseline : cases[row % cases.count]
            }
            return constructor.expression(with: arguments)
        }
    }

    // MARK: Combinatorial

    /// Rows for the full cartesian product across varied slots, the last slot
    /// varying fastest — or `nil` when a slot's cases are only known at
    /// runtime or the product exceeds the cap (the runtime form handles both).
    private static func combinatorialLiteralRows(for constructor: InstanceConstructor) -> [String]? {
        guard let product = constructor.knownCombinatorialCount,
              product <= GenerationStrategy.combinatorialCap
        else {
            return nil
        }
        let varied = constructor.variedSlotIndices
        guard !varied.isEmpty else { return [constructor.baselineExpression] }

        return (0 ..< product).map { row in
            // Decompose the row index into one digit per varied slot.
            var digits: [Int: Int] = [:]
            var remainder = row
            for index in varied.reversed() {
                let count = constructor.slots[index].generator.edgeCases.count
                digits[index] = remainder % count
                remainder /= count
            }
            let arguments = constructor.slots.enumerated().map { index, slot -> String in
                guard let digit = digits[index] else { return slot.generator.baseline }
                return slot.generator.edgeCases[digit]
            }
            return constructor.expression(with: arguments)
        }
    }

    // MARK: Runtime forms

    /// An immediately-applied closure computing one constructor's instances
    /// at runtime, for strategies that must consult a nested type's
    /// `edgeCases`. `.combinatorial` also uses it to enforce the cap.
    private static func runtimeClause(
        for constructor: InstanceConstructor,
        strategy: GenerationStrategy
    ) -> String {
        var lines = ["{ () -> [Self] in"]
        // Ordinal of each varied slot, naming its column local and loop variable.
        var ordinals: [Int: Int] = [:]
        for index in constructor.variedSlotIndices {
            let slot = constructor.slots[index]
            let ordinal = ordinals.count
            ordinals[index] = ordinal
            let annotation = slot.writtenType.map { ": [\($0)]" } ?? ""
            lines.append("        let column\(ordinal)\(annotation) = \(slot.columnExpression!)")
        }
        let columns = (0 ..< ordinals.count).map { "column\($0)" }

        switch strategy {
        case .minimal:
            let counts = columns.map { "\($0).count" }
            let count = counts.dropLast().reversed().reduce(counts.last!) { "max(\($1), \($0))" }
            lines.append("        let count = \(count)")
            lines.append("        return (0 ..< count).map { index in")
            let arguments = constructor.slots.enumerated().map { index, slot -> String in
                guard let ordinal = ordinals[index] else { return slot.generator.baseline }
                return "column\(ordinal)[index % column\(ordinal).count]"
            }
            lines.append("            \(constructor.expression(with: arguments))")
            lines.append("        }")

        case .combinatorial:
            lines.append("        var instances: [Self] = []")
            for (depth, column) in columns.enumerated() {
                let indent = String(repeating: "    ", count: depth + 2)
                let label = depth == 0 ? "loop: " : ""
                lines.append("\(indent)\(label)for value\(depth) in \(column) {")
            }
            let bodyIndent = String(repeating: "    ", count: columns.count + 2)
            lines.append("\(bodyIndent)if instances.count == \(GenerationStrategy.combinatorialCapSource) {")
            lines.append("\(bodyIndent)    break loop")
            lines.append("\(bodyIndent)}")
            let arguments = constructor.slots.enumerated().map { index, slot -> String in
                guard let ordinal = ordinals[index] else { return slot.generator.baseline }
                return "value\(ordinal)"
            }
            lines.append("\(bodyIndent)instances.append(\(constructor.expression(with: arguments)))")
            for depth in (0 ..< columns.count).reversed() {
                lines.append("\(String(repeating: "    ", count: depth + 2))}")
            }
            lines.append("        return instances")

        case .oneAtATime:
            fatalError("one-at-a-time never emits a runtime clause")
        }

        lines.append("    }()")
        return lines.joined(separator: "\n")
    }

    // MARK: Assembly

    private static func deduplicated(_ rows: [String]) -> [String] {
        var seen: Set<String> = []
        return rows.filter { seen.insert($0).inserted }
    }

    /// Concatenates the literal instance block and the runtime clauses into
    /// the expression the generated `edgeCases` returns.
    private static func assemble(literals: [String], runtimeClauses: [String]) -> String {
        var components: [String] = []
        if !literals.isEmpty {
            components.append(
                "[\n" + literals.map { "        \($0)," }.joined(separator: "\n") + "\n    ]"
            )
        }
        components.append(contentsOf: runtimeClauses)

        guard var body = components.first else { return "[]" }
        for component in components.dropFirst() {
            body += "\n    + \(component)"
        }
        return body
    }
}
