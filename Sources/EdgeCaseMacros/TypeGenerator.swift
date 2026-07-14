import SwiftSyntax

/// A source expression yielding a sequence of distinct values of a type,
/// used to populate the large `Set` and `Dictionary` edge cases.
struct DistinctValues {
    /// Element count as emitted in source, kept within the type's
    /// representable range (`Int8` cannot count to 1_000).
    let count: String
    /// Expression of a `Sequence` with `count` distinct elements,
    /// e.g. `(0 ..< 1_000).map(String.init)`.
    let values: String
}

/// Source expressions for the edge cases and baseline value of a supported
/// property type.
struct TypeGenerator {
    /// Expressions emitted while this property is the one being varied.
    let edgeCases: [String]
    /// Expression emitted while another property is being varied.
    let baseline: String
    /// Expression of type `[T]` holding edge cases only known at runtime —
    /// the `edgeCases` of a nested `EdgeCaseGeneratable` type.
    let dynamicSource: String?
    /// Distinct-value synthesis for `Set` elements and `Dictionary` keys, or
    /// `nil` for types that cannot provide enough unique values (`Bool`,
    /// optionals, collections, custom types).
    let distinct: DistinctValues?

    init(
        edgeCases: [String],
        baseline: String,
        dynamicSource: String? = nil,
        distinct: DistinctValues? = nil
    ) {
        self.edgeCases = edgeCases
        self.baseline = baseline
        self.dynamicSource = dynamicSource
        self.distinct = distinct
    }
}

extension TypeGenerator {
    /// Returns the generator for a type as written in source, or `nil` for
    /// structural types (tuples, functions, existentials) that cannot have
    /// one. Unrecognized named types are assumed to conform to
    /// `EdgeCaseGeneratable`.
    static func generator(for type: TypeSyntax) -> TypeGenerator? {
        if let optional = type.as(OptionalTypeSyntax.self) {
            return generator(for: optional.wrappedType).map(optionalGenerator(wrapping:))
        }
        if let unwrapped = type.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            return generator(for: unwrapped.wrappedType).map(optionalGenerator(wrapping:))
        }
        if let array = type.as(ArrayTypeSyntax.self) {
            return generator(for: array.element).map(arrayGenerator(of:))
        }
        if let dictionary = type.as(DictionaryTypeSyntax.self) {
            return dictionaryGenerator(keyType: dictionary.key, valueType: dictionary.value)
        }

        guard let nominal = NominalType(type) else { return nil }

        if nominal.mayBeBuiltin {
            switch (nominal.name, nominal.genericArguments.count) {
            case ("Optional", 1):
                return generator(for: nominal.genericArguments[0]).map(optionalGenerator(wrapping:))
            case ("Array", 1):
                return generator(for: nominal.genericArguments[0]).map(arrayGenerator(of:))
            case ("Set", 1):
                return generator(for: nominal.genericArguments[0]).map(setGenerator(of:))
            case ("Dictionary", 2):
                return dictionaryGenerator(
                    keyType: nominal.genericArguments[0],
                    valueType: nominal.genericArguments[1]
                )
            case (let name, 0):
                if let primitive = primitiveGenerator(named: name) {
                    return primitive
                }
            default:
                break
            }
        }
        return customGenerator(typeName: nominal.fullName)
    }

    // MARK: Composite builders

    private static func optionalGenerator(wrapping inner: TypeGenerator) -> TypeGenerator {
        TypeGenerator(
            edgeCases: ["nil"] + inner.edgeCases,
            baseline: "nil",
            dynamicSource: inner.dynamicSource
        )
    }

    private static func arrayGenerator(of element: TypeGenerator) -> TypeGenerator {
        var cases = [
            "[]",
            "[\(element.baseline)]",
            "Array(repeating: \(element.baseline), count: 1_000)",
        ]
        if let source = element.dynamicSource {
            // The all-edge-case array is only expressible when every element
            // case lives in one runtime list (custom types).
            if element.edgeCases.isEmpty {
                cases.append(source)
            }
        } else if !element.edgeCases.isEmpty {
            cases.append("[\(element.edgeCases.joined(separator: ", "))]")
        }
        return TypeGenerator(edgeCases: cases, baseline: "[]")
    }

    private static func setGenerator(of element: TypeGenerator) -> TypeGenerator {
        var cases = ["[]"]
        if let distinct = element.distinct {
            cases.append("Set(\(distinct.values))")
        }
        return TypeGenerator(edgeCases: cases, baseline: "[]")
    }

    private static func dictionaryGenerator(
        keyType: TypeSyntax,
        valueType: TypeSyntax
    ) -> TypeGenerator? {
        guard let key = generator(for: keyType), let value = generator(for: valueType) else {
            return nil
        }
        var cases = ["[:]"]
        if let distinct = key.distinct {
            cases.append(
                "Dictionary(uniqueKeysWithValues: zip(\(distinct.values), repeatElement(\(value.baseline), count: \(distinct.count))))"
            )
        }
        return TypeGenerator(edgeCases: cases, baseline: "[:]")
    }

    private static func customGenerator(typeName: String) -> TypeGenerator {
        TypeGenerator(
            edgeCases: [],
            baseline: "\(typeName).edgeCaseBaseline",
            dynamicSource: "\(typeName).edgeCases"
        )
    }

    // MARK: Primitives

    private static func primitiveGenerator(named name: String) -> TypeGenerator? {
        switch name {
        case "Int", "Int16", "Int32", "Int64":
            return TypeGenerator(
                edgeCases: ["\(name).min", "\(name).max", "0", "-1"],
                baseline: "0",
                distinct: DistinctValues(
                    count: "1_000",
                    values: name == "Int" ? "0 ..< 1_000" : "(0 ..< 1_000).map(\(name).init)"
                )
            )
        case "Int8":
            return TypeGenerator(
                edgeCases: ["Int8.min", "Int8.max", "0", "-1"],
                baseline: "0",
                distinct: DistinctValues(count: "100", values: "(0 ..< 100).map(Int8.init)")
            )
        case "Double", "Float":
            // Swift's floating point types have no `.min`/`.max`; the closest
            // equivalents are ±greatestFiniteMagnitude.
            return TypeGenerator(
                edgeCases: [
                    "-\(name).greatestFiniteMagnitude",
                    "\(name).greatestFiniteMagnitude",
                    "0",
                    "\(name).nan",
                    "\(name).infinity",
                ],
                baseline: "0",
                distinct: DistinctValues(count: "1_000", values: "(0 ..< 1_000).map(\(name).init)")
            )
        case "String":
            return TypeGenerator(
                edgeCases: [
                    #""""#,
                    #""a""#,
                    #"String(repeating: "a", count: 10_000)"#,
                    #"" \t\n""#,
                    // Emoji: ZWJ sequence, skin-tone modifier, flag.
                    #""\u{1F9D1}\u{200D}\u{1F680}\u{1F44D}\u{1F3FD}\u{1F1EC}\u{1F1F7}""#,
                    // Right-to-left text: Arabic and Hebrew.
                    #""\u{0645}\u{0631}\u{062D}\u{0628}\u{0627} \u{05E9}\u{05DC}\u{05D5}\u{05DD}""#,
                    // Zero-width space, non-joiner, joiner.
                    #""a\u{200B}b\u{200C}c\u{200D}d""#,
                    // Combining diacritic: decomposed "é".
                    #""Cafe\u{0301}""#,
                ],
                baseline: #""""#,
                distinct: DistinctValues(count: "1_000", values: "(0 ..< 1_000).map(String.init)")
            )
        case "Bool":
            return TypeGenerator(
                edgeCases: ["true", "false"],
                baseline: "false"
            )
        default:
            return nil
        }
    }
}

/// A nominal (identifier-like) type reference: `Int`, `Array<Int>`,
/// `Swift.String`, `MyModule.Address`, `Box<Int>`.
private struct NominalType {
    /// Last path component, e.g. `Address` for `MyModule.Address`.
    let name: String
    let genericArguments: [TypeSyntax]
    /// The full type as written, for use in member-access expressions.
    let fullName: String
    /// Whether the reference can denote a standard library type: it is
    /// unqualified or qualified with `Swift.`.
    let mayBeBuiltin: Bool

    init?(_ type: TypeSyntax) {
        if let identifier = type.as(IdentifierTypeSyntax.self) {
            name = identifier.name.text
            genericArguments = Self.typeArguments(of: identifier.genericArgumentClause)
            fullName = type.trimmedDescription
            mayBeBuiltin = true
            return
        }
        if let member = type.as(MemberTypeSyntax.self) {
            name = member.name.text
            genericArguments = Self.typeArguments(of: member.genericArgumentClause)
            fullName = type.trimmedDescription
            mayBeBuiltin = member.baseType.as(IdentifierTypeSyntax.self)?.name.text == "Swift"
            return
        }
        return nil
    }

    private static func typeArguments(of clause: GenericArgumentClauseSyntax?) -> [TypeSyntax] {
        guard let clause else { return [] }
        return clause.arguments.compactMap { argument in
            if case .type(let type) = argument.argument {
                return type
            }
            return nil
        }
    }
}
