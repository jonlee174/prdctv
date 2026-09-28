import Testing

struct TagTests {
    @Test func normalizeTrimsHashAndSpaces() {
        #expect(TicketTags.normalize("  #Art   History ") == "Art History")
        #expect(TicketTags.normalize("#") == "")
    }

    @Test func canonicalDedupesIgnoringCase() {
        #expect(TicketTags.canonical(["Chem101", "chem101", " ", "quiz"]) == ["Chem101", "quiz"])
    }

    @Test func canonicalReusesKnownSpelling() {
        #expect(TicketTags.canonical(["art history", "new"], known: ["Art History"]) == ["Art History", "new"])
    }

    @Test func allTagsSortsByUse() {
        let lists = [["Art History", "quiz"], ["art history"], ["quiz"], ["Art History", "errand"]]
        #expect(TicketTags.allTags(in: lists) == ["Art History", "quiz", "errand"])
    }

    @Test func colorIndexIsStableAndIgnoresCase() {
        let index = TicketTags.colorIndex(for: "Art History", count: 8)
        #expect(index == TicketTags.colorIndex(for: "art history", count: 8))
        #expect((0..<8).contains(index))
    }

    @Test func colorsRoundTripAndIgnoreCase() {
        let raw = TicketTags.encodeColors(["art history": "#112233", "quiz": "#445566"])
        #expect(TicketTags.decodeColors(raw) == ["art history": "#112233", "quiz": "#445566"])
        #expect(TicketTags.decodeColors("") == [:])
    }

    @Test func matchesIgnoresCaseAndNilMatchesAll() {
        #expect(TicketTags.matches(["Art History"], "art history"))
        #expect(!TicketTags.matches(["quiz"], "Art History"))
        #expect(TicketTags.matches([], nil))
    }

    @Test func sortedTagsIsAlphabetical() {
        #expect(TicketTags.sortedTags(in: [["quiz"], ["Art History"], ["quiz"], ["biology"]]) == ["Art History", "biology", "quiz"])
    }

    @Test func lanesGroupByFirstTagWithUntaggedLast() {
        let items = [["quiz"], [], ["Art History", "quiz"], ["art history"], ["biology"]]
        let lanes = TicketTags.lanes(Array(items.indices), tags: { items[$0] })
        #expect(lanes.map(\.tag) == ["Art History", "biology", "quiz", nil])
        #expect(lanes.map(\.items) == [[2, 3], [4], [0], [1]])
    }

    @Test func packCutsTheLastLaneInOneColumn() {
        let lanes: [(tag: String?, items: [Int])] = [("a", [1, 2]), ("b", [3, 4, 5]), (nil, [6])]
        let packed = TicketTags.pack(lanes, columns: 1, rows: 6)
        #expect(packed.count == 1)
        #expect(packed[0].map(\.tag) == ["a", "b"])
        #expect(packed[0].map(\.items) == [[1, 2], [3, 4]])
    }

    @Test func packMovesWholeLanesToTheNextColumn() {
        let lanes: [(tag: String?, items: [Int])] = [("a", [1, 2]), ("b", [3, 4, 5]), (nil, [6])]
        let packed = TicketTags.pack(lanes, columns: 3, rows: 4)
        #expect(packed.map { $0.map(\.tag) } == [["a"], ["b"], [nil]])
        #expect(packed[1][0].items == [3, 4, 5])
    }

    @Test func quickAddKeepsTagCase() {
        #expect(QuickAddParser().parse("worksheet 3 #ALG2 #alg2").tags == ["ALG2"])
    }
}
