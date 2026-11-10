import Foundation

/// How far apart repeats are.
enum RepeatUnit: String, CaseIterable, Identifiable {
    case day, week, month

    var id: String { rawValue }

    var component: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }

    func name(count: Int) -> String {
        let singular = rawValue
        return count == 1 ? singular : singular + "s"
    }
}

/// A ticket's repeat, such as every 2 weeks. Daily, weekly and monthly are every 1 of a unit.
struct RepeatRule: Equatable {
    var every: Int
    var unit: RepeatUnit

    static let daily = RepeatRule(every: 1, unit: .day)
    static let weekly = RepeatRule(every: 1, unit: .week)
    static let monthly = RepeatRule(every: 1, unit: .month)

    var label: String {
        switch (every, unit) {
        case (1, .day): "Daily"
        case (1, .week): "Weekly"
        case (1, .month): "Monthly"
        default: "Every \(every) \(unit.name(count: every))"
        }
    }

    /// The copy's due date, whole intervals after the old due date (or the finish day without one) and after the finish day.
    func nextDue(after due: Date?, finishedAt finished: Date, calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: finished)
        let start = calendar.startOfDay(for: due ?? finished)
        // Steps are counted from the start each time, so a month end stays put within one catch up.
        var steps = 1
        while true {
            let next = calendar.date(byAdding: unit.component, value: max(every, 1) * steps, to: start) ?? today
            if next > today || steps >= 10_000 { return next }
            steps += 1
        }
    }
}
