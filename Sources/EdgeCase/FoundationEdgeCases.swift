import Foundation

// Bundled conformances for the Foundation types that appear in almost every
// production model. `EdgeCaseGeneratable` is this library's protocol, so
// conforming types we don't own to it is safe (no retroactive-conformance
// clash with other modules is possible unless they also depend on EdgeCase).
//
// In each list the first element is the neutral value, because the protocol's
// default `edgeCaseBaseline` is the first edge case.

extension Date: EdgeCaseGeneratable {
    /// The epoch, moments around it, the extremes, and the 32-bit rollover.
    public static var edgeCases: [Date] {
        [
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: -1),
            .distantPast,
            .distantFuture,
            Date(timeIntervalSince1970: 2_147_483_648), // past the Y2038 32-bit rollover
        ]
    }
}

extension URL: EdgeCaseGeneratable {
    /// A plain URL, a scheme-less single character, ports/escapes/duplicate
    /// query keys/fragments, internationalized host + encoded emoji path, a
    /// 2,000-character path, and a file URL.
    public static var edgeCases: [URL] {
        [
            URL(string: "https://example.com")!,
            URL(string: "a")!,
            URL(string: "https://user@example.com:8443/a%20b/c?q=1&q=2#frag")!,
            URL(string: "https://xn--bcher-kva.example/%F0%9F%9A%80")!,
            URL(string: "https://example.com/" + String(repeating: "a", count: 2_000))!,
            URL(fileURLWithPath: "/"),
        ]
    }
}

extension UUID: EdgeCaseGeneratable {
    /// The nil UUID, the all-ones UUID, and a minimal v4-shaped one.
    public static var edgeCases: [UUID] {
        [
            UUID(uuidString: "00000000-0000-0000-0000-000000000000")!,
            UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!,
            UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
        ]
    }
}
