import SwiftDiagnostics

enum EdgeCasesDiagnostic: DiagnosticMessage {
    case notAStruct
    case missingTypeAnnotation(property: String)
    case unsupportedPattern
    case unsupportedType(property: String, type: String)

    var message: String {
        switch self {
        case .notAStruct:
            return "'@EdgeCases' can only be attached to a struct"
        case .missingTypeAnnotation(let property):
            return "stored property '\(property)' needs an explicit type annotation to be included in edge case generation"
        case .unsupportedPattern:
            return "'@EdgeCases' does not support tuple patterns in stored property declarations"
        case .unsupportedType(let property, let type):
            return "'@EdgeCases' has no generator for type '\(type)' of stored property '\(property)' (supported: Int, Int8, Int16, Int32, Int64, Double, Float, String, Bool)"
        }
    }

    var diagnosticID: MessageID {
        let id: String
        switch self {
        case .notAStruct: id = "notAStruct"
        case .missingTypeAnnotation: id = "missingTypeAnnotation"
        case .unsupportedPattern: id = "unsupportedPattern"
        case .unsupportedType: id = "unsupportedType"
        }
        return MessageID(domain: "EdgeCaseMacros", id: id)
    }

    var severity: DiagnosticSeverity { .error }
}
