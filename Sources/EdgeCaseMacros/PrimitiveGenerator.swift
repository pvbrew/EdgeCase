/// A stored property of the annotated struct that participates in edge case
/// generation.
struct StoredProperty {
    let name: String
    let generator: PrimitiveGenerator
}

/// Source expressions for the edge cases and baseline value of a supported
/// primitive type.
struct PrimitiveGenerator {
    /// Expressions emitted while this property is the one being varied.
    let edgeCases: [String]
    /// Expression emitted while another property is being varied.
    let baseline: String

    /// Returns the generator for a type as written in source, or `nil` if the
    /// type is not supported in v0.1.
    static func generator(forTypeNamed rawName: String) -> PrimitiveGenerator? {
        let name = rawName.hasPrefix("Swift.") ? String(rawName.dropFirst("Swift.".count)) : rawName
        switch name {
        case "Int", "Int8", "Int16", "Int32", "Int64":
            return PrimitiveGenerator(
                edgeCases: ["\(name).min", "\(name).max", "0", "-1"],
                baseline: "0"
            )
        case "Double", "Float":
            // Swift's floating point types have no `.min`/`.max`; the closest
            // equivalents are ±greatestFiniteMagnitude.
            return PrimitiveGenerator(
                edgeCases: [
                    "-\(name).greatestFiniteMagnitude",
                    "\(name).greatestFiniteMagnitude",
                    "0",
                    "\(name).nan",
                    "\(name).infinity",
                ],
                baseline: "0"
            )
        case "String":
            return PrimitiveGenerator(
                edgeCases: [
                    #""""#,
                    #""a""#,
                    #"String(repeating: "a", count: 10_000)"#,
                    #"" \t\n""#,
                ],
                baseline: #""""#
            )
        case "Bool":
            return PrimitiveGenerator(
                edgeCases: ["true", "false"],
                baseline: "false"
            )
        default:
            return nil
        }
    }
}
