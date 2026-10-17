import Foundation

/// Short due date text for tight spaces like widget rows.
enum DueLabel {
    /// The weekday for dates in the next 7 days including today, a short date otherwise.
    static func text(for due: Date, now: Date = Date(), calendar: Calendar = .current, locale: Locale = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = locale
        let days = daysAway(due, now: now, calendar: calendar)
        formatter.setLocalizedDateFormatFromTemplate((0...6).contains(days) ? "EEE" : "MMMd")
        return formatter.string(from: due)
    }

    static func isOverdue(_ due: Date, now: Date = Date(), calendar: Calendar = .current) -> Bool {
        daysAway(due, now: now, calendar: calendar) < 0
    }

    /// Whole days from today to the due day, negative when overdue.
    static func daysAway(_ due: Date, now: Date, calendar: Calendar) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: calendar.startOfDay(for: due)).day ?? 0
    }
}

/// Due dates picked by month and day, without a year.
enum DueDates {
    /// The next date with this month and day, today included, skipping years where it doesn't exist (Feb 29).
    static func nextOccurrence(month: Int, day: Int, from now: Date = Date(), calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: now)
        let year = calendar.component(.year, from: today)
        for candidate in year...(year + 8) {
            guard let date = calendar.date(from: DateComponents(year: candidate, month: month, day: day)),
                  calendar.component(.month, from: date) == month,
                  calendar.component(.day, from: date) == day else { continue }
            if date >= today { return date }
        }
        return nil
    }

    /// Days offered for a month, with Feb 29 allowed since some year has it.
    static func maxDay(inMonth month: Int) -> Int {
        switch month {
        case 2: 29
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}
