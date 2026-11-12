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
    var tags: [String] = []
    var dueDate: Date?
}

struct BoardEntry: TimelineEntry {
    let date: Date
    let engine: RewardEngine
    let upNext: [TicketSnapshot]
    let inProgress: [TicketSnapshot]
    /// From the app's Settings, shared by every prdctv widget.
    var layout = WidgetLayout.columns
    var statusTitles = true
    var statusShowsTags = true
    var showsMiscellaneous = true
    var tagOrder = TagLaneOrder()
    var rewardsEnabled = true
    var pointsEnabled = true
    /// Whether the large widget shows the reward meter.
    var showsLargeMeterSetting = true

    var largeShowsMeter: Bool { rewardsEnabled && showsLargeMeterSetting }

    var upNextNeed: [TicketSnapshot] { upNext.filter { $0.category == .need } }

    /// Open tickets under their first tag, In Progress before Up Next inside each tag.
    /// In Progress then Up Next, each soonest due first. Without titles the sections still keep that order.
    var statusSections: [(tag: String?, items: [TicketSnapshot])] {
        [("In Progress", inProgress), ("Up Next", upNext)]
            .map { (tag: $0.0, items: TicketTags.byDueDate($0.1, dueDate: \.dueDate)) }
            .filter { !$0.items.isEmpty }
    }

    var tagLanes: [(tag: String?, items: [TicketSnapshot])] {
        TicketTags.lanes(inProgress + upNext, tags: \.tags, dueDate: \.dueDate, order: tagOrder)
            .filter { $0.tag != nil || showsMiscellaneous }
    }

}

// Static on purpose. An AppIntentConfiguration widget never got its settings from chronod in development builds.
struct BoardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(context.isPreview ? .sample : Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        // App and intent writes reload immediately. This refresh also rolls weekday labels over at midnight.
        let calendar = Calendar.current
        let hourLater = calendar.date(byAdding: .hour, value: 1, to: Date())!
        let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        let next = min(hourLater, midnight)
        completion(Timeline(entries: [Self.load()], policy: .after(next)))
    }

    static func load() -> BoardEntry {
        // A fresh container per load so we always read the app's latest writes.
        let context = ModelContext(SharedStore.makeContainer())
        let tickets = (try? context.fetch(FetchDescriptor<Ticket>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let redemptions = (try? context.fetch(FetchDescriptor<Redemption>())) ?? []

        let rewardsEnabled = RewardSettings.isEnabled()
        func snapshots(_ status: Status) -> [TicketSnapshot] {
            // Tickets on hold stay off the widget.
            tickets.filter { $0.status == status && !$0.onHold && (rewardsEnabled || !$0.category.isReward) }.map {
                TicketSnapshot(id: $0.id, title: $0.title, category: $0.category,
                               points: $0.points, locked: $0.isLocked(redemptions: redemptions), tags: $0.tags,
                               dueDate: $0.dueDate)
            }
        }

        return BoardEntry(
            date: Date(),
            engine: RewardEngine(tickets: tickets, redemptions: redemptions, settings: .load()),
            upNext: snapshots(.upNext),
            inProgress: snapshots(.inProgress),
            layout: WidgetLayout.load(),
            statusTitles: AppGroup.defaults.object(forKey: TicketTags.widgetStatusTitlesKey) as? Bool ?? true,
            statusShowsTags: AppGroup.defaults.object(forKey: TicketTags.widgetStatusShowsTagsKey) as? Bool ?? true,
            showsMiscellaneous: AppGroup.defaults.object(forKey: TicketTags.widgetShowsMiscellaneousKey) as? Bool ?? true,
            tagOrder: TagLaneOrder.load(),
            rewardsEnabled: rewardsEnabled,
            pointsEnabled: RewardSettings.pointsEnabled(),
            showsLargeMeterSetting: AppGroup.defaults.object(forKey: RewardSettings.largeWidgetShowsMeterKey) as? Bool ?? true
        )
    }
}

extension BoardEntry {
    static let sample: BoardEntry = {
        func t(_ title: String, _ cat: Category, _ pts: Int, locked: Bool = false, tags: [String] = [], dueIn: Int? = nil) -> TicketSnapshot {
            let due = dueIn.flatMap { Calendar.current.date(byAdding: .day, value: $0, to: Calendar.current.startOfDay(for: Date())) }
            return TicketSnapshot(id: UUID(), title: title, category: cat, points: pts, locked: locked, tags: tags, dueDate: due)
        }
        return BoardEntry(
            date: Date(),
            engine: RewardEngine(needPointsDone: 11, redeemedWant: 1, redeemedFun: 0),
            upNext: [t("Study for chemistry quiz", .need, 3, tags: ["Chemistry"], dueIn: 1), t("Call the dentist", .need, 1, dueIn: -1),
                     t("Renew passport", .need, 2, tags: ["errand"]), t("Rewatch a favorite movie", .want, 2, locked: true)],
            inProgress: [t("Algebra worksheet", .need, 8, tags: ["Algebra"], dueIn: 12), t("Board game night", .fun, 1)]
        )
    }()
}
