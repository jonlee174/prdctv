import Foundation
import Testing

struct DueLabelTests {
    // Friday 2026-10-16, noon.
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        return cal
    }()
    let locale = Locale(identifier: "en_US")
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 12))! }

    func day(_ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 9))!
    }

    func label(_ date: Date) -> String {
        DueLabel.text(for: date, now: now, calendar: calendar, locale: locale)
    }

    @Test func weekdayForTheComingWeek() {
        #expect(label(day(10, 16)) == "Fri")
        #expect(label(day(10, 17)) == "Sat")
        #expect(label(day(10, 22)) == "Thu")
    }

    @Test func dateFromAWeekOut() {
        #expect(label(day(10, 23)) == "Oct 23")
        #expect(label(day(11, 2)) == "Nov 2")
    }

    @Test func nextOccurrenceIsTodayOrLater() {
        #expect(DueDates.nextOccurrence(month: 10, day: 16, from: now, calendar: calendar) == calendar.startOfDay(for: day(10, 16)))
        #expect(DueDates.nextOccurrence(month: 12, day: 25, from: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2026, month: 12, day: 25)))
        #expect(DueDates.nextOccurrence(month: 10, day: 1, from: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2027, month: 10, day: 1)))
    }

    @Test func leapDayWaitsForALeapYear() {
        #expect(DueDates.nextOccurrence(month: 2, day: 29, from: now, calendar: calendar)
                == calendar.date(from: DateComponents(year: 2028, month: 2, day: 29)))
        #expect(DueDates.nextOccurrence(month: 2, day: 30, from: now, calendar: calendar) == nil)
    }

    @Test func overdueShowsTheDate() {
        #expect(label(day(10, 15)) == "Oct 15")
        #expect(DueLabel.isOverdue(day(10, 15), now: now, calendar: calendar))
        #expect(!DueLabel.isOverdue(day(10, 16), now: now, calendar: calendar))
    }
}
