import Foundation
import Testing

struct QuickAddParserTests {
    // Thursday 2026-09-24, noon.
    let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()
    var now: Date { calendar.date(from: DateComponents(year: 2026, month: 9, day: 24, hour: 12))! }
    var parser: QuickAddParser { QuickAddParser(now: now, calendar: calendar) }

    func day(_ month: Int, _ day: Int, _ year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    @Test func needIsDefault() {
        let r = parser.parse("write book report 5")
        #expect(r == .init(title: "write book report", category: .need, points: 5, tags: [], dueDate: nil))
    }

    @Test func wantPrefix() {
        let r = parser.parse("w: rewatch a movie 2")
        #expect(r.category == .want)
        #expect(r.title == "rewatch a movie")
        #expect(r.points == 2)
    }

    @Test func funWithoutPointsDefaultsToOne() {
        let r = parser.parse("f: board game night")
        #expect(r.category == .fun)
        #expect(r.title == "board game night")
        #expect(r.points == 1)
    }

    @Test func tagsAndDue() {
        let r = parser.parse("n: study for chemistry quiz 3 #chem !fri")
        #expect(r.category == .need)
        #expect(r.title == "study for chemistry quiz")
        #expect(r.points == 3)
        #expect(r.tags == ["chem"])
        #expect(r.dueDate == day(9, 25))
    }

    @Test func numbersOffScaleStayInTitle() {
        let r = parser.parse("read chapter 12")
        #expect(r.title == "read chapter 12")
        #expect(r.points == 1)
    }

    @Test func loneNumberIsATitle() {
        #expect(parser.parse("42").title == "42")
        #expect(parser.parse("3").title == "3")
    }

    @Test func prefixIsCaseInsensitive() {
        #expect(parser.parse("W: nap").category == .want)
    }

    @Test func dueFormats() {
        #expect(parser.parseDue("today") == day(9, 24))
        #expect(parser.parseDue("tmr") == day(9, 25))
        #expect(parser.parseDue("thu") == day(9, 24))   // today counts
        #expect(parser.parseDue("wed") == day(9, 30))   // next week
        #expect(parser.parseDue("3d") == day(9, 27))
        #expect(parser.parseDue("2026-10-03") == day(10, 3))
        #expect(parser.parseDue("10/3") == day(10, 3))
        #expect(parser.parseDue("1/5") == day(1, 5, 2027)) // already passed → next year
        #expect(parser.parseDue("13/40") == nil)
        #expect(parser.parseDue("banana") == nil)
    }

    @Test func trailingNumberStaysInTitleWithoutPoints() {
        var parser = parser
        parser.parsesPoints = false
        let r = parser.parse("read chapter 3")
        #expect(r.title == "read chapter 3")
        #expect(r.points == 1)
    }

    @Test func unknownBangStaysInTitle() {
        let r = parser.parse("ship it !now")
        #expect(r.title == "ship it !now")
        #expect(r.dueDate == nil)
    }
}
