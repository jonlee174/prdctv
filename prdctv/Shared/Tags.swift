import Foundation

/// Tag rules shared by the editor, quick add, and the widget.
enum TicketTags {
    /// Trims, drops a leading "#", and collapses inner whitespace. Case is kept so class codes read as typed.
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Normalizes, drops duplicates ignoring case, and reuses the spelling of a matching known tag.
    static func canonical(_ tags: [String], known: [String] = []) -> [String] {
        var spelling: [String: String] = [:]
        for tag in known where spelling[tag.lowercased()] == nil { spelling[tag.lowercased()] = tag }
        var seen: Set<String> = []
        var result: [String] = []
        for raw in tags {
            let tag = normalize(raw)
            let key = tag.lowercased()
            guard !tag.isEmpty, seen.insert(key).inserted else { continue }
            result.append(spelling[key] ?? tag)
        }
        return result
    }

    /// Every tag in use, most used first, one spelling per tag.
    static func allTags(in tagLists: [[String]]) -> [String] {
        var counts: [String: Int] = [:]
        var spelling: [String: String] = [:]
        for tag in tagLists.joined() {
            let key = tag.lowercased()
            counts[key, default: 0] += 1
            if spelling[key] == nil { spelling[key] = tag }
        }
        return counts.keys
            .sorted { counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : $0 < $1 }
            .map { spelling[$0]! }
    }

    /// Every tag in use, alphabetical.
    static func sortedTags(in tagLists: [[String]]) -> [String] {
        allTags(in: tagLists).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    /// Groups items by their first tag, ordered by `order`, with untagged last.
    static func lanes<Item>(_ items: [Item], tags: (Item) -> [String], dueDate: (Item) -> Date? = { _ in nil },
                            order: TagLaneOrder = TagLaneOrder()) -> [(tag: String?, items: [Item])] {
        let groups = Dictionary(grouping: items) { tags($0).first?.lowercased() }
        func sortedItems(_ list: [Item]) -> [Item] {
            order.tasks == .dueDate ? byDueDate(list, dueDate: dueDate) : list
        }
        func soonest(_ key: String) -> Date { groups[key]!.compactMap(dueDate).min() ?? .distantFuture }
        let names = order.sorted(sortedTags(in: items.compactMap { tags($0).first.map { [$0] } }), soonest: soonest)
        var lanes: [(tag: String?, items: [Item])] = names.map { (tag: $0, items: sortedItems(groups[$0.lowercased()]!)) }
        if let untagged = groups[nil] { lanes.append((tag: nil, items: sortedItems(untagged))) }
        return lanes
    }

    /// Soonest due first, undated last, ties keep their order.
    static func byDueDate<Item>(_ items: [Item], dueDate: (Item) -> Date?) -> [Item] {
        items.enumerated()
            .sorted { (dueDate($0.element) ?? .distantFuture, $0.offset) < (dueDate($1.element) ?? .distantFuture, $1.offset) }
            .map(\.element)
    }

    /// Fits lanes into columns of `rows` lines each, a heading taking `headingLines` lines and a cut lane keeping its first items.
    static func pack<Item>(_ lanes: [(tag: String?, items: [Item])], columns: Int, rows: Int,
                           headingLines: Int = 1) -> [[(tag: String?, items: [Item])]] {
        var packed: [[(tag: String?, items: [Item])]] = []
        var current: [(tag: String?, items: [Item])] = []
        var left = rows
        for lane in lanes {
            // Start a new column rather than cut a lane, while columns remain.
            if headingLines + lane.items.count > left, !current.isEmpty, packed.count + 1 < columns {
                packed.append(current)
                current = []
                left = rows
            }
            guard left >= headingLines + 1 else { break }
            let shown = min(lane.items.count, left - headingLines)
            current.append((tag: lane.tag, items: Array(lane.items.prefix(shown))))
            left -= headingLines + shown
        }
        if !current.isEmpty { packed.append(current) }
        return packed
    }

    /// Whether a ticket's tags include `tag`, ignoring case. A nil tag matches everything.
    static func matches(_ tags: [String], _ tag: String?) -> Bool {
        guard let tag else { return true }
        return tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    /// Settings keys for tag lane order, stored where the widget can read them.
    static let tagOrderKey = "tagOrder"
    static let tagPriorityKey = "tagPriority"
    static let tagTaskOrderKey = "tagTaskOrder"

    /// Settings key for showing tag lane headings as plain bold text instead of colored chips.
    static let plainLaneTitlesKey = "tagLanePlainTitles"

    /// Settings keys for the widget's layouts, set in the app's Settings and read by the widget.
    static let widgetLayoutKey = "widgetLayout"
    /// Older on or off switch for the tag layout, read when `widgetLayout` was never set.
    static let widgetListByTagKey = "widgetListByTag"
    /// By status layout shows In Progress and Up Next titles. On by default.
    static let widgetStatusTitlesKey = "widgetStatusTitles"
    /// By status layout shows tags in rows. On by default.
    static let widgetStatusShowsTagsKey = "widgetStatusShowsTags"
    static let widgetShowsMiscellaneousKey = "widgetShowsMiscellaneous"
    /// Widget rows show due dates. Off by default.
    static let widgetShowsDueDatesKey = "widgetShowsDueDates"

    /// Tasks take their first tag's color, or standard green without a tag. On by default.
    static let colorTasksByTagKey = "colorTasksByTag"

    /// Settings key for chosen tag colors, stored as one "tag\t#RRGGBB" line per tag.
    static let colorsKey = "tagColors"

    /// Chosen colors keyed by lowercased tag.
    static func decodeColors(_ raw: String) -> [String: String] {
        var colors: [String: String] = [:]
        for line in raw.split(separator: "\n") {
            let parts = line.split(separator: "\t", maxSplits: 1).map(String.init)
            if parts.count == 2 { colors[parts[0].lowercased()] = parts[1] }
        }
        return colors
    }

    /// Tags can't hold tabs or newlines because `normalize` collapses whitespace.
    static func encodeColors(_ colors: [String: String]) -> String {
        colors.keys.sorted().map { "\($0)\t\(colors[$0]!)" }.joined(separator: "\n")
    }

    /// Stable palette index for a tag, the same in every process and ignoring case.
    static func colorIndex(for tag: String, count: Int) -> Int {
        // FNV-1a, because Swift's hashValue changes between launches.
        var hash: UInt32 = 2_166_136_261
        for byte in tag.lowercased().utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16_777_619
        }
        return Int(hash % UInt32(count))
    }
}

/// How tag lanes are ordered on the board and in the widget, and how tasks are ordered inside them.
struct TagLaneOrder: Equatable {
    enum Tags: String { case custom, dueDate }
    enum Tasks: String { case board, dueDate }

    var tags: Tags = .custom
    var tasks: Tasks = .board
    /// Lowercased tags in the user's priority order. Tags not listed come after, alphabetical.
    var priority: [String] = []

    init(tags: Tags = .custom, tasks: Tasks = .board, priority: [String] = []) {
        self.tags = tags
        self.tasks = tasks
        self.priority = priority
    }

    init(tagsRaw: String, tasksRaw: String, priorityRaw: String) {
        self.init(tags: Tags(rawValue: tagsRaw) ?? .custom, tasks: Tasks(rawValue: tasksRaw) ?? .board,
                  priority: Self.decodePriority(priorityRaw))
    }

    static func load(_ defaults: UserDefaults = AppGroup.defaults) -> TagLaneOrder {
        TagLaneOrder(tagsRaw: defaults.string(forKey: TicketTags.tagOrderKey) ?? "",
                     tasksRaw: defaults.string(forKey: TicketTags.tagTaskOrderKey) ?? "",
                     priorityRaw: defaults.string(forKey: TicketTags.tagPriorityKey) ?? "")
    }

    /// One lowercased tag per line.
    static func decodePriority(_ raw: String) -> [String] {
        raw.split(separator: "\n").map { $0.lowercased() }
    }

    static func encodePriority(_ tags: [String]) -> String {
        tags.map { $0.lowercased() }.joined(separator: "\n")
    }

    /// Tags in priority order, unranked ones after in alphabetical order.
    func byPriority(_ names: [String]) -> [String] {
        let rank = Dictionary(priority.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return names.sorted {
            let a = rank[$0.lowercased()] ?? .max, b = rank[$1.lowercased()] ?? .max
            return a != b ? a < b : $0.localizedStandardCompare($1) == .orderedAscending
        }
    }

    /// Orders lane names. `soonest` gives a tag's earliest due date, keyed by lowercased tag.
    func sorted(_ names: [String], soonest: (String) -> Date) -> [String] {
        let custom = byPriority(names)
        guard tags == .dueDate else { return custom }
        let position = Dictionary(custom.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        return custom.sorted { (soonest($0.lowercased()), position[$0]!) < (soonest($1.lowercased()), position[$1]!) }
    }
}

/// How the medium, large and extra large widgets list tickets.
enum WidgetLayout: String, CaseIterable {
    /// Up Next and In Progress lists, the original layout.
    case columns
    /// Open tickets under bold tag titles.
    case tags
    /// Open tickets under In Progress and Up Next titles, each sorted by due date.
    case status

    static func load(_ defaults: UserDefaults = AppGroup.defaults) -> WidgetLayout {
        if let raw = defaults.string(forKey: TicketTags.widgetLayoutKey), let layout = WidgetLayout(rawValue: raw) {
            return layout
        }
        return defaults.bool(forKey: TicketTags.widgetListByTagKey) ? .tags : .columns
    }
}
