import Foundation

/// Undo history for a setting: the values it had before each change, newest last.
///
/// Stored as a single string (newline-separated, "∅" for an empty value) so it fits in
/// @AppStorage and survives closing Settings. Changes that arrive within `burst` of the
/// previous one count as a single edit, so dragging around the color wheel undoes in one step.
struct UndoHistory: Equatable {
    static let limit = 20
    static let burst: TimeInterval = 1

    private(set) var raw: String

    init(raw: String = "") {
        self.raw = raw
    }

    var entries: [String] {
        raw.isEmpty ? [] : raw.components(separatedBy: "\n").map { $0 == "∅" ? "" : $0 }
    }

    var canUndo: Bool { !raw.isEmpty }

    /// Records `previous` as the value to return to, unless this change continues an edit
    /// that started less than `burst` ago.
    mutating func record(_ previous: String, at now: Date, lastChange: Date?) {
        if let lastChange, now.timeIntervalSince(lastChange) < Self.burst { return }
        store(Array((entries + [previous]).suffix(Self.limit)))
    }

    /// Removes and returns the most recent previous value.
    mutating func pop() -> String? {
        var list = entries
        guard let last = list.popLast() else { return nil }
        store(list)
        return last
    }

    private mutating func store(_ list: [String]) {
        raw = list.map { $0.isEmpty ? "∅" : $0 }.joined(separator: "\n")
    }
}
