import Foundation
import SwiftData

enum DemoData {
    @MainActor
    static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: Date())! }

        let rows: [(String, Category, Int, Status, [String])] = [
            ("Study for chemistry quiz", .need, 3, .upNext, ["Chemistry", "quiz"]),
            ("Write book report", .need, 5, .inProgress, ["English"]),
            ("Call the dentist", .need, 1, .upNext, []),
            ("Algebra worksheet", .need, 8, .upNext, ["Algebra"]),
            ("Renew passport", .need, 2, .upNext, ["errand"]),
            ("Rewatch a favorite movie", .want, 2, .upNext, []),
            ("New running shoes", .want, 3, .upNext, []),
            ("Board game night", .fun, 1, .upNext, []),
            ("Weekend hike", .fun, 2, .upNext, []),
        ]
        for (i, row) in rows.enumerated() {
            let t = Ticket(title: row.0, category: row.1, points: row.2, status: row.3, sortIndex: Double(i), tags: row.4)
            let dueIn = ["Study for chemistry quiz": 1, "Algebra worksheet": 3, "Renew passport": 6,
                         "Call the dentist": -1, "Weekend hike": 2, "Write book report": 1]
            if let days = dueIn[row.0] {
                t.dueDate = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date()))
            }
            if row.0 == "Algebra worksheet" { t.repeatRule = .weekly }
            t.onHold = row.0 == "Renew passport"
            context.insert(t)
        }

        // Completed history across recent weeks for stats and rewards.
        let done: [(String, Int, Int)] = [
            ("Laundry", 2, 0), ("Read chapter 3", 3, 0), ("Water the plants", 2, 1),
            ("Science project", 5, 2), ("Groceries", 1, 3), ("Oil change", 2, 9),
            ("Study for history test", 8, 12), ("Clean desk", 3, 16), ("Taxes", 5, 24),
        ]
        for (i, row) in done.enumerated() {
            let t = Ticket(title: row.0, category: .need, points: row.1, status: .done, sortIndex: Double(100 + i))
            t.completedAt = daysAgo(row.2)
            t.dueDate = cal.startOfDay(for: daysAgo(row.2))
            context.insert(t)
        }
        let movie = Ticket(title: "Movie night", category: .want, points: 2, status: .done, sortIndex: 200)
        movie.completedAt = daysAgo(8)
        context.insert(movie)
        context.insert(Redemption(kind: .want, ticketID: movie.id, redeemedAt: daysAgo(9)))
        try? context.save()
    }
}
