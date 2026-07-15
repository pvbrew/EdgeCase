import EdgeCase
import EdgeCaseTesting
import Testing

@EdgeCases
struct Ping: Equatable {
    let id: Int
    let note: String
}

@Suite("LabeledEdgeCase")
struct LabeledEdgeCaseTests {

    @Test func labelsCarryPositionAndAbbreviatedDescription() {
        let labeled = Ping.labeledEdgeCases
        #expect(labeled.count == Ping.edgeCases.count)
        #expect(labeled.map(\.value) == Ping.edgeCases, "wrapping must not reorder or drop cases")

        for (index, edgeCase) in labeled.enumerated() {
            #expect(edgeCase.index == index)
            #expect(edgeCase.testDescription.hasPrefix("[\(index)] "))
        }
    }

    @Test func labelsStayShortForHugeInstances() throws {
        let huge = Ping.labeledEdgeCases.first { $0.value.note.count == 10_000 }
        let label = try #require(huge).testDescription
        #expect(label.count < 100, "a 10,000-character note must not flood test output")
        #expect(label.hasSuffix("…"))
    }

    @Test func labelsCollapseNewlines() {
        let label = LabeledEdgeCase(index: 3, value: "line one\nline two").testDescription
        #expect(!label.contains("\n"))
        #expect(label == "[3] line one line two")
    }

    // The roadmap's parameterized-test support, driven end-to-end: labeled
    // edge cases feed `@Test(arguments:)` directly.
    @Test(arguments: Ping.labeledEdgeCases)
    func drivesParameterizedTests(_ edgeCase: LabeledEdgeCase<Ping>) {
        #expect(!edgeCase.testDescription.isEmpty)
        #expect(Ping.edgeCases.contains(edgeCase.value))
    }

    // Composed cases (fixture + one adversary at a time) work as arguments
    // too — `edgeCases(varying:)` returns a plain `[Self]`.
    @Test(arguments: Ping.edgeCases(varying: Ping(id: 7, note: "realistic")))
    func composedCasesWorkAsArguments(_ ping: Ping) {
        #expect(ping.id == 7 || ping.note == "realistic",
                "every composed case keeps the base value in all but one property")
    }
}
