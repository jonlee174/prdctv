import Foundation
import Testing

struct UndoHistoryTests {
    let t0 = Date(timeIntervalSinceReferenceDate: 0)

    @Test func undoReturnsPreviousValuesNewestFirst() {
        var h = UndoHistory()
        h.record("", at: t0, lastChange: nil)                          // default → red
        h.record("#FF0000", at: t0 + 5, lastChange: t0)                // red → blue
        h.record("#0000FF", at: t0 + 10, lastChange: t0 + 5)           // blue → green
        #expect(h.pop() == "#0000FF")
        #expect(h.pop() == "#FF0000")
        #expect(h.pop() == "")                                          // back to the default
        #expect(h.pop() == nil)
        #expect(!h.canUndo)
    }

    @Test func rapidChangesCountAsOneEdit() {
        var h = UndoHistory()
        // Dragging on the color wheel: the first change records where we started, the rest merge.
        h.record("#111111", at: t0, lastChange: nil)
        h.record("#222222", at: t0 + 0.2, lastChange: t0)
        h.record("#333333", at: t0 + 0.4, lastChange: t0 + 0.2)
        #expect(h.entries == ["#111111"])
        // A pause longer than the burst window starts a new edit.
        h.record("#444444", at: t0 + 3, lastChange: t0 + 0.4)
        #expect(h.entries == ["#111111", "#444444"])
    }

    @Test func survivesRoundTripThroughStorage() {
        var h = UndoHistory()
        h.record("", at: t0, lastChange: nil)
        h.record("#ABCDEF|book.fill", at: t0 + 5, lastChange: nil)
        let restored = UndoHistory(raw: h.raw)
        #expect(restored.entries == ["", "#ABCDEF|book.fill"])
    }

    @Test func keepsOnlyRecentEdits() {
        var h = UndoHistory()
        for i in 0..<30 {
            h.record(String(format: "#%06X", i), at: t0 + Double(i * 5), lastChange: nil)
        }
        #expect(h.entries.count == UndoHistory.limit)
        #expect(h.entries.last == String(format: "#%06X", 29))
    }
}
