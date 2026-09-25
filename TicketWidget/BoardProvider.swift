import Foundation
import SwiftData
import WidgetKit

/// Value snapshot of a ticket, so widget views never hold SwiftData models.
struct TicketSnapshot: Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: Category
    let points: Int
    let locked: Bool
}

struct BoardEntry: TimelineEntry {
    let date: Date
    let engine: RewardEngine
    let upNext: [TicketSnapshot]
    let inProgress: [TicketSnapshot]
    let doneThisWeek: [TicketSnapshot]

    var upNextNeed: [TicketSnapshot] { upNext.filter { $0.category == .need } }
}

struct BoardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(context.isPreview ? .sample : Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        // App and intent writes reload immediately; this is just a safety refresh
        // (e.g. so Done rolls over at the start of a week).
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [Self.load()], policy: .after(next)))
    }

    static func load() -> BoardEntry {
        // A fresh container per load so we always read the app's latest writes.
        let context = ModelContext(SharedStore.makeContainer())
        let tickets = (try? context.fetch(FetchDescriptor<Ticket>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let redemptions = (try? context.fetch(FetchDescriptor<Redemption>())) ?? []

        func snapshots(_ status: Status) -> [TicketSnapshot] {
            tickets.filter { $0.status == status }.map {
                TicketSnapshot(id: $0.id, title: $0.title, category: $0.category,
                               points: $0.points, locked: $0.isLocked(redemptions: redemptions))
            }
        }

        let calendar = Calendar.current
        let done = tickets
            .filter { t in t.status == .done && t.completedAt.map { calendar.isDate($0, equalTo: Date(), toGranularity: .weekOfYear) } == true }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            .map { TicketSnapshot(id: $0.id, title: $0.title, category: $0.category, points: $0.points, locked: false) }

        return BoardEntry(
            date: Date(),
            engine: RewardEngine(tickets: tickets, redemptions: redemptions, settings: .load()),
            upNext: snapshots(.upNext),
            inProgress: snapshots(.inProgress),
            doneThisWeek: done
        )
    }
}

extension BoardEntry {
    static let sample: BoardEntry = {
        func t(_ title: String, _ cat: Category, _ pts: Int, locked: Bool = false) -> TicketSnapshot {
            TicketSnapshot(id: UUID(), title: title, category: cat, points: pts, locked: locked)
        }
        return BoardEntry(
            date: Date(),
            engine: RewardEngine(needPointsDone: 11, redeemedWant: 1, redeemedFun: 0),
            upNext: [t("Grade CS 212 quizzes", .need, 3), t("Finish lattice writeup", .need, 5),
                     t("Email advisor", .need, 1), t("Rewatch Arrival", .want, 2, locked: true)],
            inProgress: [t("Problem set 4", .need, 8), t("Pickup basketball", .fun, 1)],
            doneThisWeek: [t("Laundry", .need, 2), t("Read chapter 3", .need, 3)]
        )
    }()
}
