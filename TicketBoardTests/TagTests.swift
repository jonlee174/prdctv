import Testing

struct TagTests {
    @Test func normalizeTrimsHashAndSpaces() {
        #expect(TicketTags.normalize("  #CS   212 ") == "CS 212")
        #expect(TicketTags.normalize("#") == "")
    }

    @Test func canonicalDedupesIgnoringCase() {
        #expect(TicketTags.canonical(["CS212", "cs212", " ", "ta"]) == ["CS212", "ta"])
    }

    @Test func canonicalReusesKnownSpelling() {
        #expect(TicketTags.canonical(["cs 212", "new"], known: ["CS 212"]) == ["CS 212", "new"])
    }

    @Test func allTagsSortsByUse() {
        let lists = [["CS 212", "ta"], ["cs 212"], ["ta"], ["CS 212", "errand"]]
        #expect(TicketTags.allTags(in: lists) == ["CS 212", "ta", "errand"])
    }

    @Test func colorIndexIsStableAndIgnoresCase() {
        let index = TicketTags.colorIndex(for: "CS 212", count: 8)
        #expect(index == TicketTags.colorIndex(for: "cs 212", count: 8))
        #expect((0..<8).contains(index))
    }

    @Test func colorsRoundTripAndIgnoreCase() {
        let raw = TicketTags.encodeColors(["cs 212": "#112233", "ta": "#445566"])
        #expect(TicketTags.decodeColors(raw) == ["cs 212": "#112233", "ta": "#445566"])
        #expect(TicketTags.decodeColors("") == [:])
    }

    @Test func matchesIgnoresCaseAndNilMatchesAll() {
        #expect(TicketTags.matches(["CS 212"], "cs 212"))
        #expect(!TicketTags.matches(["ta"], "CS 212"))
        #expect(TicketTags.matches([], nil))
    }

    @Test func sortedTagsIsAlphabetical() {
        #expect(TicketTags.sortedTags(in: [["ta"], ["CS 212"], ["ta"], ["art"]]) == ["art", "CS 212", "ta"])
    }

    @Test func lanesGroupByFirstTagWithUntaggedLast() {
        let items = [["ta"], [], ["CS 212", "ta"], ["cs 212"], ["art"]]
        let lanes = TicketTags.lanes(Array(items.indices), tags: { items[$0] })
        #expect(lanes.map(\.tag) == ["art", "CS 212", "ta", nil])
        #expect(lanes.map(\.items) == [[4], [2, 3], [0], [1]])
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
        #expect(QuickAddParser().parse("pset 3 #MATH340 #math340").tags == ["MATH340"])
    }
}
