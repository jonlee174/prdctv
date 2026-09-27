import Foundation

/// The days shown for one month: whole weeks from the locale's first weekday,
/// including the trailing/leading days of neighboring months.
struct MonthGrid: Equatable {
    let monthStart: Date
    let days: [Date]
    let calendar: Calendar

    init(containing date: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        let start = calendar.dateInterval(of: .month, for: date)!.start
        monthStart = start

        let dayCount = calendar.range(of: .day, in: .month, for: start)!.count
        let leading = (calendar.component(.weekday, from: start) - calendar.firstWeekday + 7) % 7
        let cells = Int(ceil(Double(leading + dayCount) / 7)) * 7
        let gridStart = calendar.date(byAdding: .day, value: -leading, to: start)!
        days = (0..<cells).map { calendar.date(byAdding: .day, value: $0, to: gridStart)! }
    }

    var weeks: [[Date]] {
        stride(from: 0, to: days.count, by: 7).map { Array(days[$0..<$0 + 7]) }
    }

    func contains(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: monthStart, toGranularity: .month)
    }

    /// Weekday initials ordered from the locale's first weekday.
    var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    func adding(months: Int) -> MonthGrid {
        MonthGrid(containing: calendar.date(byAdding: .month, value: months, to: monthStart)!, calendar: calendar)
    }

    static func == (lhs: MonthGrid, rhs: MonthGrid) -> Bool {
        lhs.monthStart == rhs.monthStart && lhs.calendar == rhs.calendar
    }
}
