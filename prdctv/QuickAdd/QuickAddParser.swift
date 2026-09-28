import Foundation

/// Parses quick-add syntax:
///
///     write book report 5                        → Need, 5 pts (need is the default)
///     w: rewatch a movie 2                       → Want, 2 pts
///     f: board game night                        → Fun, 1 pt
///     n: study for chemistry quiz 3 #chem !fri   → Need, 3 pts, tag "chem", due Friday
///
/// Points are only taken from the last bare number, and only if it's on the point scale,
/// so "read chapter 12" keeps its number in the title.
/// Due dates: !today, !tomorrow/!tmr, !mon…!sun (next occurrence, today included),
/// !3d (days from now), !2026-10-03, !10/3.
struct QuickAddParser {
    struct Result: Equatable {
        var title: String
        var category: Category
        var points: Int
        var tags: [String]
        var dueDate: Date?

        var isEmpty: Bool { title.isEmpty }
    }

    var now: Date = Date()
    var calendar: Calendar = .current
    /// Off while points are hidden, so a trailing number stays in the title.
    var parsesPoints = RewardSettings.pointsEnabled()

    func parse(_ input: String) -> Result {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var category = Category.need

        let prefixes: [(String, Category)] = [("n:", .need), ("w:", .want), ("f:", .fun)]
        if let (prefix, cat) = prefixes.first(where: { text.lowercased().hasPrefix($0.0) }) {
            category = cat
            text = String(text.dropFirst(prefix.count))
        }

        var words: [String] = []
        var tags: [String] = []
        var dueDate: Date?

        for token in text.split(whereSeparator: \.isWhitespace).map(String.init) {
            if token.count > 1, token.hasPrefix("#") {
                tags.append(TicketTags.normalize(token))
            } else if token.count > 1, token.hasPrefix("!"), let date = parseDue(String(token.dropFirst())) {
                dueDate = date
            } else {
                words.append(token)
            }
        }

        var points = 1
        if parsesPoints, let last = words.last, let value = Int(last), PointScale.values.contains(value), words.count > 1 {
            points = value
            words.removeLast()
        }

        return Result(
            title: words.joined(separator: " "),
            category: category,
            points: points,
            tags: TicketTags.canonical(tags),
            dueDate: dueDate
        )
    }

    func parseDue(_ raw: String) -> Date? {
        let token = raw.lowercased()
        let today = calendar.startOfDay(for: now)

        switch token {
        case "today", "tod": return today
        case "tomorrow", "tmr", "tom": return calendar.date(byAdding: .day, value: 1, to: today)
        default: break
        }

        let weekdays = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]
        if let index = weekdays.firstIndex(where: { token.hasPrefix($0) }) {
            let target = index + 1 // Calendar weekday: Sunday = 1
            let current = calendar.component(.weekday, from: today)
            let delta = (target - current + 7) % 7
            return calendar.date(byAdding: .day, value: delta, to: today)
        }

        if token.hasSuffix("d"), let days = Int(token.dropLast()) {
            return calendar.date(byAdding: .day, value: days, to: today)
        }

        let iso = DateFormatter()
        iso.calendar = calendar
        iso.timeZone = calendar.timeZone
        iso.dateFormat = "yyyy-MM-dd"
        if let date = iso.date(from: token) { return date }

        let parts = token.split(separator: "/").compactMap { Int($0) }
        if parts.count == 2, (1...12).contains(parts[0]), (1...31).contains(parts[1]) {
            let year = calendar.component(.year, from: today)
            var comps = DateComponents(year: year, month: parts[0], day: parts[1])
            if let date = calendar.date(from: comps), date >= today { return date }
            comps.year = year + 1 // already passed this year → next year
            return calendar.date(from: comps)
        }
        return nil
    }
}
