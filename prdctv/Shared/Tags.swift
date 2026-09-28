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

    /// Groups items by their first tag, alphabetical with untagged last, keeping order inside each group.
    static func lanes<Item>(_ items: [Item], tags: (Item) -> [String]) -> [(tag: String?, items: [Item])] {
        let groups = Dictionary(grouping: items) { tags($0).first?.lowercased() }
        var lanes: [(tag: String?, items: [Item])] = sortedTags(in: items.compactMap { tags($0).first.map { [$0] } })
            .map { (tag: $0, items: groups[$0.lowercased()]!) }
        if let untagged = groups[nil] { lanes.append((tag: nil, items: untagged)) }
        return lanes
    }

    /// Fits lanes into columns of `rows` lines each, a heading taking one line and a cut lane keeping its first items.
    static func pack<Item>(_ lanes: [(tag: String?, items: [Item])], columns: Int, rows: Int) -> [[(tag: String?, items: [Item])]] {
        var packed: [[(tag: String?, items: [Item])]] = []
        var current: [(tag: String?, items: [Item])] = []
        var left = rows
        for lane in lanes {
            // Start a new column rather than cut a lane, while columns remain.
            if 1 + lane.items.count > left, !current.isEmpty, packed.count + 1 < columns {
                packed.append(current)
                current = []
                left = rows
            }
            guard left >= 2 else { break }
            let shown = min(lane.items.count, left - 1)
            current.append((tag: lane.tag, items: Array(lane.items.prefix(shown))))
            left -= 1 + shown
        }
        if !current.isEmpty { packed.append(current) }
        return packed
    }

    /// Whether a ticket's tags include `tag`, ignoring case. A nil tag matches everything.
    static func matches(_ tags: [String], _ tag: String?) -> Bool {
        guard let tag else { return true }
        return tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }

    /// Settings key for showing tag lane headings as plain bold text instead of colored chips.
    static let plainLaneTitlesKey = "tagLanePlainTitles"

    /// Settings keys for the widget's List by Tag layout, set in the app's Settings and read by the widget.
    static let widgetListByTagKey = "widgetListByTag"
    static let widgetShowsMiscellaneousKey = "widgetShowsMiscellaneous"

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
