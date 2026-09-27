import Foundation
import Testing

struct MonthGridTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        cal.locale = Locale(identifier: "en_US")
        cal.firstWeekday = firstWeekday
        return cal
    }

    func day(_ cal: Calendar, _ y: Int, _ m: Int, _ d: Int) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d))!
    }

    @Test func septemberStartingSunday() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthGrid(containing: day(cal, 2026, 9, 25), calendar: cal)
        // Sep 1 2026 is a Tuesday: two leading days from August.
        #expect(grid.days.first == day(cal, 2026, 8, 30))
        #expect(grid.days.count == 35)
        #expect(grid.days.last == day(cal, 2026, 10, 3))
        #expect(grid.weeks.count == 5)
        #expect(grid.contains(day(cal, 2026, 9, 1)))
        #expect(!grid.contains(day(cal, 2026, 8, 31)))
        #expect(grid.weekdaySymbols.first == "Sun")
    }

    @Test func mondayFirstLocale() {
        let cal = calendar(firstWeekday: 2)
        let grid = MonthGrid(containing: day(cal, 2026, 9, 1), calendar: cal)
        #expect(grid.days.first == day(cal, 2026, 8, 31))
        #expect(grid.weekdaySymbols.first == "Mon")
        #expect(grid.weekdaySymbols.last == "Sun")
    }

    @Test func sixWeekMonth() {
        // Aug 2026 starts on a Saturday and has 31 days → 6 rows with Sunday-first weeks.
        let cal = calendar(firstWeekday: 1)
        let grid = MonthGrid(containing: day(cal, 2026, 8, 15), calendar: cal)
        #expect(grid.weeks.count == 6)
    }

    @Test func navigatesAcrossYears() {
        let cal = calendar(firstWeekday: 1)
        let grid = MonthGrid(containing: day(cal, 2026, 12, 10), calendar: cal).adding(months: 1)
        #expect(grid.monthStart == day(cal, 2027, 1, 1))
    }
}
