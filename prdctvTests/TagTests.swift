import Foundation
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

    // Items are (tags, days until due) pairs for the lane order tests.
    typealias Item = (tags: [String], due: Int?)
    let base = Date(timeIntervalSinceReferenceDate: 0)
    func lanes(_ items: [Item], _ order: TagLaneOrder) -> [(tag: String?, items: [Int])] {
        let indexed = Array(items.indices)
        return TicketTags.lanes(indexed, tags: { items[$0].tags },
                                dueDate: { items[$0].due.map { self.base.addingTimeInterval(Double($0) * 86_400) } },
                                order: order)
            .map { (tag: $0.tag, items: $0.items) }
    }
    let sample: [Item] = [(["quiz"], 5), (["Art"], nil), ([], 1), (["biology"], 2), (["quiz"], 1), (["Art"], 9)]

    @Test func customOrderFollowsPriorityThenAlphabetical() {
        let order = TagLaneOrder(priority: ["quiz"])
        #expect(lanes(sample, order).map(\.tag) == ["quiz", "Art", "biology", nil])
        #expect(lanes(sample, TagLaneOrder()).map(\.tag) == ["Art", "biology", "quiz", nil])
    }

    @Test func dueDateOrderPutsTheSoonestTagFirst() {
        let order = TagLaneOrder(tags: .dueDate)
        // quiz has a task due in 1 day, biology in 2, Art in 9.
        #expect(lanes(sample, order).map(\.tag) == ["quiz", "biology", "Art", nil])
    }

    @Test func tasksByDueDateKeepBoardOrderForTies() {
        let order = TagLaneOrder(tasks: .dueDate)
        let result = lanes(sample, order)
        #expect(result.first { $0.tag == "quiz" }?.items == [4, 0])
        #expect(result.first { $0.tag == "Art" }?.items == [5, 1])
        #expect(lanes(sample, TagLaneOrder()).first { $0.tag == "quiz" }?.items == [0, 4])
    }

    @Test func priorityRoundTrips() {
        let raw = TagLaneOrder.encodePriority(["Quiz", "Art History"])
        #expect(TagLaneOrder.decodePriority(raw) == ["quiz", "art history"])
        #expect(TagLaneOrder(tagsRaw: "bogus", tasksRaw: "", priorityRaw: "").tags == .custom)
    }

    @Test func untitledSectionsTakeNoHeadingLine() {
        let sections: [(tag: String?, items: [Int])] = [("In Progress", [1, 2]), ("Up Next", [3, 4, 5])]
        #expect(TicketTags.pack(sections, columns: 1, rows: 4, headingLines: 0).first?.map(\.items) == [[1, 2], [3, 4]])
        #expect(TicketTags.pack(sections, columns: 1, rows: 5).first?.map(\.items) == [[1, 2], [3]])
    }

    @Test func byDueDatePutsUndatedLastAndKeepsTies() {
        let dates: [Int?] = [nil, 3, 1, 3, nil]
        let sorted = TicketTags.byDueDate(Array(dates.indices)) { dates[$0].map { self.base.addingTimeInterval(Double($0)) } }
        #expect(sorted == [2, 1, 3, 0, 4])
    }

    @Test func widgetLayoutFallsBackToTheOldSwitch() {
        let defaults = UserDefaults(suiteName: "WidgetLayoutTest")!
        defaults.removePersistentDomain(forName: "WidgetLayoutTest")
        #expect(WidgetLayout.load(defaults) == .columns)
        defaults.set(true, forKey: TicketTags.widgetListByTagKey)
        #expect(WidgetLayout.load(defaults) == .tags)
        defaults.set("status", forKey: TicketTags.widgetLayoutKey)
        #expect(WidgetLayout.load(defaults) == .status)
    }
}
