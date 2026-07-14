import SwiftDiagnostics

enum EdgeCasesDiagnostic: DiagnosticMessage {
    case unsupportedDeclaration
    case missingTypeAnnotation(property: String)
    case unsupportedPattern
    case unsupportedType(property: String, type: String)
    case unsupportedAssociatedValueType(enumCase: String, type: String)
    case enumWithoutCases

    var message: String {
        switch self {
        case .unsupportedDeclaration:
            return "'@EdgeCases' can only be attached to a struct or an enum"
        case .missingTypeAnnotation(let property):
            return "stored property '\(property)' needs an explicit type annotation to be included in edge case generation"
        case .unsupportedPattern:
            return "'@EdgeCases' does not support tuple patterns in stored property declarations"
        case .unsupportedType(let property, let type):
            return "'@EdgeCases' has no generator for type '\(type)' of stored property '\(property)' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable')"
        case .unsupportedAssociatedValueType(let enumCase, let type):
            return "'@EdgeCases' has no generator for type '\(type)' in associated values of case '\(enumCase)' (tuples, functions, and existentials are not supported; use a named type conforming to 'EdgeCaseGeneratable')"
        case .enumWithoutCases:
            return "'@EdgeCases' requires an enum to declare at least one case"
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
        }
        return MessageID(domain: "EdgeCaseMacros", id: id)
    }

    var severity: DiagnosticSeverity { .error }
}
