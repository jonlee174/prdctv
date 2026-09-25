import Foundation
import SwiftData

enum DemoData {
    @MainActor
    static func seed(_ context: ModelContext) {
        let cal = Calendar.current
        func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: Date())! }

        let rows: [(String, Category, Int, Status, [String])] = [
            ("Grade CS 212 quizzes", .need, 3, .upNext, ["ta"]),
            ("Finish lattice writeup", .need, 5, .inProgress, ["research"]),
            ("Email advisor about defense date", .need, 1, .upNext, []),
            ("Problem set 4", .need, 8, .backlog, []),
            ("Renew passport", .need, 2, .backlog, ["errand"]),
            ("Rewatch Arrival", .want, 2, .upNext, []),
            ("New climbing shoes", .want, 3, .backlog, []),
            ("Pickup basketball", .fun, 1, .backlog, []),
            ("Weekend hike", .fun, 2, .upNext, []),
        ]
        for (i, row) in rows.enumerated() {
            let t = Ticket(title: row.0, category: row.1, points: row.2, status: row.3, sortIndex: Double(i), tags: row.4)
            if row.0 == "Grade CS 212 quizzes" { t.dueDate = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) }
            context.insert(t)
        }

        // Completed history across recent weeks for stats and rewards.
        let done: [(String, Int, Int)] = [
            ("Laundry", 2, 0), ("Read chapter 3", 3, 0), ("Office hours prep", 2, 1),
            ("Lab report", 5, 2), ("Groceries", 1, 3), ("Review PR", 2, 9),
            ("Midterm study", 8, 12), ("Clean desk", 3, 16), ("Taxes", 5, 24),
        ]
        for (i, row) in done.enumerated() {
            let t = Ticket(title: row.0, category: .need, points: row.1, status: .done, sortIndex: Double(100 + i))
            t.completedAt = daysAgo(row.2)
            context.insert(t)
        }
        let movie = Ticket(title: "Movie night", category: .want, points: 2, status: .done, sortIndex: 200)
        movie.completedAt = daysAgo(8)
        context.insert(movie)
        context.insert(Redemption(kind: .want, ticketID: movie.id, redeemedAt: daysAgo(9)))
        try? context.save()
    }
}
