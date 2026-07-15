import SwiftDiagnostics

enum EdgeCasesDiagnostic: DiagnosticMessage {
    // Declaration-level errors.
    case unsupportedDeclaration
    case missingTypeAnnotation(property: String)
    case unsupportedPattern
    case unsupportedType(property: String, type: String)
    case unsupportedAssociatedValueType(enumCase: String, type: String)
    case enumWithoutCases
    case invalidStrategy

    // Override errors.
    case invalidOverride
    case customOverrideNotArrayLiteral
    case customOverrideEmpty
    case duplicateOverride(property: String)
    case excludeNeedsValue(property: String, type: String)

    // Warnings.
    case overrideOnFixedConstant(property: String)
    case overrideOnNonStoredProperty(property: String)
    case unsupportedTypeUsesDefault(property: String, type: String)
    case combinatorialCapExceeded(count: Int)

    var message: String {
        switch self {
        case .unsupportedDeclaration:
            return "'@EdgeCases' can only be attached to a struct or an enum"
        case .missingTypeAnnotation(let property):
            return "stored property '\(property)' needs an explicit type annotation to be included in edge case generation"
        case .unsupportedPattern:
            return "'@EdgeCases' does not support tuple patterns in stored property declarations"
        case .unsupportedType(let property, let type):
            return "'@EdgeCases' has no generator for type '\(type)' of stored property '\(property)' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable', or attach '@EdgeCase(.custom([...]))')"
        case .unsupportedAssociatedValueType(let enumCase, let type):
            return "'@EdgeCases' has no generator for type '\(type)' in associated values of case '\(enumCase)' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable')"
        case .enumWithoutCases:
            return "'@EdgeCases' requires an enum to declare at least one case"
        case .invalidStrategy:
            return "'strategy' must be written as '.oneAtATime', '.minimal', or '.combinatorial'"
        case .invalidOverride:
            return "'@EdgeCase' expects a single '.custom([...])' or '.exclude' override"
        case .customOverrideNotArrayLiteral:
            return "'.custom' requires its values written as an array literal, e.g. '.custom([0, 150])'"
        case .customOverrideEmpty:
            return "'.custom' needs at least one value; the first value doubles as the property's baseline"
        case .duplicateOverride(let property):
            return "'\(property)' has more than one '@EdgeCase' attribute; only one override is allowed per property"
        case .excludeNeedsValue(let property, let type):
            return "'@EdgeCase(.exclude)' on '\(property)' needs a default value, because '\(type)' has no built-in baseline to hold the property at"
        case .overrideOnFixedConstant(let property):
            return "'@EdgeCase' has no effect on '\(property)': constants with a default value always keep their fixed value"
        case .overrideOnNonStoredProperty(let property):
            return "'@EdgeCase' has no effect on '\(property)': only stored instance properties participate in edge case generation"
        case .unsupportedTypeUsesDefault(let property, let type):
            return "'@EdgeCases' has no generator for type '\(type)'; '\(property)' keeps its default value in every generated instance (attach '@EdgeCase(.custom([...]))' to vary it, or '@EdgeCase(.exclude)' to silence this warning)"
        case .combinatorialCapExceeded(let count):
            return "'.combinatorial' would generate \(count) instances; generation is capped at 1_000 (consider '.minimal', '.oneAtATime', or '@EdgeCase(.exclude)' on noisy properties)"
        }
    }

    var diagnosticID: MessageID {
        let id: String
        switch self {
        case .unsupportedDeclaration: id = "unsupportedDeclaration"
        case .missingTypeAnnotation: id = "missingTypeAnnotation"
        case .unsupportedPattern: id = "unsupportedPattern"
        case .unsupportedType: id = "unsupportedType"
        case .unsupportedAssociatedValueType: id = "unsupportedAssociatedValueType"
        case .enumWithoutCases: id = "enumWithoutCases"
        case .invalidStrategy: id = "invalidStrategy"
        case .invalidOverride: id = "invalidOverride"
        case .customOverrideNotArrayLiteral: id = "customOverrideNotArrayLiteral"
        case .customOverrideEmpty: id = "customOverrideEmpty"
        case .duplicateOverride: id = "duplicateOverride"
        case .excludeNeedsValue: id = "excludeNeedsValue"
        case .overrideOnFixedConstant: id = "overrideOnFixedConstant"
        case .overrideOnNonStoredProperty: id = "overrideOnNonStoredProperty"
        case .unsupportedTypeUsesDefault: id = "unsupportedTypeUsesDefault"
        case .combinatorialCapExceeded: id = "combinatorialCapExceeded"
        }
        return MessageID(domain: "EdgeCaseMacros", id: id)
    }

    var severity: DiagnosticSeverity {
        switch self {
        case .overrideOnFixedConstant, .overrideOnNonStoredProperty,
             .unsupportedTypeUsesDefault, .combinatorialCapExceeded:
            return .warning
        default:
            return .error
        }
    }
}
