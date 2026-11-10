import Foundation
import Testing

struct RepeatTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    func day(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func copyGoesToUpNextWithTheSameDetails() throws {
        let done = Ticket(title: "Book report", notes: "Two pages", category: .want, points: 3, status: .done,
                          dueDate: day(11, 6), tags: ["English"])
        done.repeatRule = .weekly
        let copy = try #require(done.repeatCopy(sortIndex: 7, finishedAt: day(11, 5), calendar: calendar))
        #expect(copy.title == "Book report" && copy.notes == "Two pages")
        #expect(copy.category == .want && copy.points == 3 && copy.tags == ["English"])
        #expect(copy.status == .upNext && copy.completedAt == nil && copy.sortIndex == 7)
        #expect(copy.repeatRule == .weekly && copy.dueDate == day(11, 13) && copy.id != done.id)
    }

    @Test func ticketsDoNotRepeatByDefault() {
        let ticket = Ticket(title: "Algebra homework")
        #expect(ticket.repeatRule == nil && ticket.repeatCopy(sortIndex: 1) == nil)
    }

    @Test func ruleRoundTripsThroughTheTicket() {
        let ticket = Ticket(title: "Chemistry lab")
        ticket.repeatRule = RepeatRule(every: 3, unit: .month)
        #expect(ticket.repeatRule == RepeatRule(every: 3, unit: .month))
        ticket.repeatRule = nil
        #expect(ticket.repeatRule == nil && ticket.repeatEvery == 0)
    }

    @Test func nextDueKeepsTheScheduleWhenFinishedEarlyOrOnTime() {
        #expect(RepeatRule.daily.nextDue(after: day(11, 10), finishedAt: day(11, 10), calendar: calendar) == day(11, 11))
        #expect(RepeatRule.weekly.nextDue(after: day(11, 13), finishedAt: day(11, 11), calendar: calendar) == day(11, 20))
        #expect(RepeatRule(every: 2, unit: .week).nextDue(after: day(11, 13), finishedAt: day(11, 13), calendar: calendar) == day(11, 27))
    }

    @Test func nextDueSkipsPastIntervalsWhenFinishedLate() {
        #expect(RepeatRule.weekly.nextDue(after: day(11, 2), finishedAt: day(11, 11), calendar: calendar) == day(11, 16))
        #expect(RepeatRule.daily.nextDue(after: day(11, 1), finishedAt: day(11, 10), calendar: calendar) == day(11, 11))
    }

    @Test func nextDueWithoutADateCountsFromTheFinishDay() {
        #expect(RepeatRule(every: 3, unit: .day).nextDue(after: nil, finishedAt: day(11, 10), calendar: calendar) == day(11, 13))
    }

    @Test func monthlyClampsToTheMonthEnd() {
        #expect(RepeatRule.monthly.nextDue(after: day(1, 31), finishedAt: day(1, 30), calendar: calendar) == day(2, 28))
        #expect(RepeatRule.monthly.nextDue(after: day(1, 31), finishedAt: day(3, 1), calendar: calendar) == day(3, 31))
    }

    @Test func labels() {
        #expect(RepeatRule.daily.label == "Daily" && RepeatRule.weekly.label == "Weekly" && RepeatRule.monthly.label == "Monthly")
        #expect(RepeatRule(every: 3, unit: .day).label == "Every 3 days")
        #expect(RepeatRule(every: 2, unit: .month).label == "Every 2 months")
    }
}
