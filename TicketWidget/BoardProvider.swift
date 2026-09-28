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
}

struct BoardEntry: TimelineEntry {
    let date: Date
    let engine: RewardEngine
    let upNext: [TicketSnapshot]
    let inProgress: [TicketSnapshot]
    /// From the app's Settings, shared by every prdctv widget.
    var listByTag = false
    var showsMiscellaneous = true
    var rewardsEnabled = true
    var pointsEnabled = true
    /// Whether the large widget shows the reward meter.
    var showsLargeMeterSetting = true

    var largeShowsMeter: Bool { rewardsEnabled && showsLargeMeterSetting }

    var upNextNeed: [TicketSnapshot] { upNext.filter { $0.category == .need } }

    /// Open tickets under their first tag, In Progress before Up Next inside each tag.
    var tagLanes: [(tag: String?, items: [TicketSnapshot])] {
        TicketTags.lanes(inProgress + upNext, tags: \.tags).filter { $0.tag != nil || showsMiscellaneous }
    }

}

// Static on purpose. An AppIntentConfiguration widget never got its settings from chronod in development builds.
struct BoardProvider: TimelineProvider {
    func placeholder(in context: Context) -> BoardEntry { .sample }

    func getSnapshot(in context: Context, completion: @escaping (BoardEntry) -> Void) {
        completion(context.isPreview ? .sample : Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BoardEntry>) -> Void) {
        // App and intent writes reload immediately; this is just a safety refresh.
        let next = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
        completion(Timeline(entries: [Self.load()], policy: .after(next)))
    }

    static func load() -> BoardEntry {
        // A fresh container per load so we always read the app's latest writes.
        let context = ModelContext(SharedStore.makeContainer())
        let tickets = (try? context.fetch(FetchDescriptor<Ticket>(sortBy: [SortDescriptor(\.sortIndex)]))) ?? []
        let redemptions = (try? context.fetch(FetchDescriptor<Redemption>())) ?? []

        let rewardsEnabled = RewardSettings.isEnabled()
        func snapshots(_ status: Status) -> [TicketSnapshot] {
            tickets.filter { $0.status == status && (rewardsEnabled || !$0.category.isReward) }.map {
                TicketSnapshot(id: $0.id, title: $0.title, category: $0.category,
                               points: $0.points, locked: $0.isLocked(redemptions: redemptions), tags: $0.tags)
            }
        }

        return BoardEntry(
            date: Date(),
            engine: RewardEngine(tickets: tickets, redemptions: redemptions, settings: .load()),
            upNext: snapshots(.upNext),
            inProgress: snapshots(.inProgress),
            listByTag: AppGroup.defaults.bool(forKey: TicketTags.widgetListByTagKey),
            showsMiscellaneous: AppGroup.defaults.object(forKey: TicketTags.widgetShowsMiscellaneousKey) as? Bool ?? true,
            rewardsEnabled: rewardsEnabled,
            pointsEnabled: RewardSettings.pointsEnabled(),
            showsLargeMeterSetting: AppGroup.defaults.object(forKey: RewardSettings.largeWidgetShowsMeterKey) as? Bool ?? true
        )
    }
}

extension BoardEntry {
    static let sample: BoardEntry = {
        func t(_ title: String, _ cat: Category, _ pts: Int, locked: Bool = false, tags: [String] = []) -> TicketSnapshot {
            TicketSnapshot(id: UUID(), title: title, category: cat, points: pts, locked: locked, tags: tags)
        }
        return BoardEntry(
            date: Date(),
            engine: RewardEngine(needPointsDone: 11, redeemedWant: 1, redeemedFun: 0),
            upNext: [t("Grade quizzes", .need, 3, tags: ["CS 212"]), t("Finish lattice writeup", .need, 5),
                     t("Email advisor", .need, 1), t("Rewatch Arrival", .want, 2, locked: true)],
            inProgress: [t("Problem set 4", .need, 8, tags: ["MATH 340"]), t("Pickup basketball", .fun, 1)]
        )
    }()
}
