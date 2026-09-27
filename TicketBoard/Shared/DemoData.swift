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
            ("Problem set 4", .need, 8, .upNext, []),
            ("Renew passport", .need, 2, .upNext, ["errand"]),
            ("Rewatch Arrival", .want, 2, .upNext, []),
            ("New climbing shoes", .want, 3, .upNext, []),
            ("Pickup basketball", .fun, 1, .upNext, []),
            ("Weekend hike", .fun, 2, .upNext, []),
        ]
        for (i, row) in rows.enumerated() {
            let t = Ticket(title: row.0, category: row.1, points: row.2, status: row.3, sortIndex: Double(i), tags: row.4)
            let dueIn = ["Grade CS 212 quizzes": 1, "Problem set 4": 3, "Renew passport": 6,
                         "Email advisor about defense date": -1, "Weekend hike": 2, "Finish lattice writeup": 1]
            if let days = dueIn[row.0] {
                t.dueDate = cal.date(byAdding: .day, value: days, to: cal.startOfDay(for: Date()))
            }
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

// TODO: remove once every device has launched a build containing this (added 2026-09-26).
enum LeakedDemoCleanup {
    /// Before in-memory stores set `cloudKitDatabase: .none`, one `--demo` run on 2026-09-27 03:15:36 UTC
    /// uploaded its sample records to iCloud. They were all created within the same millisecond,
    /// so match on both the demo title and that creation window; nothing else can fall in it.
    private static let window = Date(timeIntervalSinceReferenceDate: 812_171_736.0)
        ..< Date(timeIntervalSinceReferenceDate: 812_171_737.0)

    private static let titles: Set<String> = [
        "Grade CS 212 quizzes", "Finish lattice writeup", "Email advisor about defense date",
        "Problem set 4", "Renew passport", "Rewatch Arrival", "New climbing shoes",
        "Pickup basketball", "Weekend hike", "Laundry", "Read chapter 3", "Office hours prep",
        "Lab report", "Groceries", "Review PR", "Midterm study", "Clean desk", "Taxes", "Movie night",
    ]

    @MainActor
    static func run(_ context: ModelContext) {
        let tickets = (try? context.fetch(FetchDescriptor<Ticket>())) ?? []
        let leaked = tickets.filter { titles.contains($0.title) && window.contains($0.createdAt) }
        guard !leaked.isEmpty else { return }

        let ids = Set(leaked.map(\.id))
        let redemptions = TicketOps.allRedemptions(context: context).filter { $0.ticketID.map(ids.contains) == true }
        redemptions.forEach(context.delete)
        leaked.forEach(context.delete)
        TicketOps.save(context)
        print("LeakedDemoCleanup: removed \(leaked.count) demo tickets and \(redemptions.count) redemptions")
    }
}
