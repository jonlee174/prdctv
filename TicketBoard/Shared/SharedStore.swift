import Foundation
import Observation
import SwiftData
import WidgetKit

/// The single SwiftData store shared by the app and the widget extension via the App Group container.
enum SharedStore {
    static let schema = Schema([Ticket.self, Redemption.self])

    private static let widgetWriteKey = "widgetWroteAt"

    /// - Parameter syncsWithICloud: only the apps sync. The widget reads and writes the same
    ///   local store, and the app's CloudKit mirroring exports those changes next time it runs.
    static func makeContainer(inMemory: Bool = false, syncsWithICloud: Bool = false) -> ModelContainer {
        if inMemory {
            // cloudKitDatabase must be explicit: the default (.automatic) syncs any store,
            // even an in-memory one, whenever the app has the iCloud entitlement.
            return open(ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none))
        }
        guard FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id) != nil else {
            // Missing App Group entitlement (e.g. an unsigned build): use a private store the
            // widget can't see. It gets its own file name, because the generic default
            // location (~/Library/Application Support/default.store outside the sandbox)
            // may belong to another app.
            return open(ModelConfiguration(schema: schema, url: fallbackStoreURL, cloudKitDatabase: .none))
        }
        let group = ModelConfiguration.GroupContainer.identifier(AppGroup.id)
        if syncsWithICloud {
            let synced = ModelConfiguration(
                schema: schema, groupContainer: group,
                cloudKitDatabase: .private(AppGroup.cloudKitContainer)
            )
            if let container = try? ModelContainer(for: schema, configurations: synced) {
                return container
            }
            // e.g. no iCloud entitlement in this build: keep working locally.
        }
        return open(ModelConfiguration(schema: schema, groupContainer: group, cloudKitDatabase: .none))
    }

    private static var fallbackStoreURL: URL {
        let dir = URL.applicationSupportDirectory.appending(path: "TicketBoard", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appending(path: "TicketBoard.store")
    }

    private static func open(_ config: ModelConfiguration) -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not open ticket store: \(error)")
        }
    }

    /// Called by the widget process after it writes, so the app knows to reload
    /// (SwiftData contexts don't observe other processes' writes).
    static func markWidgetWrite() {
        AppGroup.defaults.set(Date().timeIntervalSince1970, forKey: widgetWriteKey)
    }

    static var lastWidgetWrite: Date {
        Date(timeIntervalSince1970: AppGroup.defaults.double(forKey: widgetWriteKey))
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// Owns the app's container. SwiftData contexts don't see writes from the widget process,
/// so the container is swapped for a fresh one whenever the widget has written since it
/// was opened; views key off `generation` to rebuild their queries.
@MainActor
@Observable
final class StoreController {
    private(set) var container: ModelContainer
    private(set) var generation = 0
    let isDemo: Bool
    private var loadedAt = Date()

    init(demo: Bool) {
        LegacySettingsMigration.run()
        isDemo = demo
        container = SharedStore.makeContainer(inMemory: demo, syncsWithICloud: true)
        if demo { DemoData.seed(container.mainContext) } else { LeakedDemoCleanup.run(container.mainContext) }
        TicketOps.migrateBacklog(context: container.mainContext)
    }

    func refreshIfNeeded() {
        guard !isDemo, SharedStore.lastWidgetWrite > loadedAt else { return }
        container = SharedStore.makeContainer(syncsWithICloud: true)
        TicketOps.migrateBacklog(context: container.mainContext)
        loadedAt = Date()
        generation += 1
    }
}

/// Ticket mutations shared by the app, menu bar, quick add, and widget intents,
/// so ordering and reward rules live in one place.
@MainActor
enum TicketOps {
    static func tickets(in status: Status, context: ModelContext) -> [Ticket] {
        let raw = status.rawValue
        let descriptor = FetchDescriptor<Ticket>(
            predicate: #Predicate { $0.statusRaw == raw },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    static func allRedemptions(context: ModelContext) -> [Redemption] {
        (try? context.fetch(FetchDescriptor<Redemption>())) ?? []
    }

    static func engine(context: ModelContext) -> RewardEngine {
        let tickets = (try? context.fetch(FetchDescriptor<Ticket>())) ?? []
        return RewardEngine(tickets: tickets, redemptions: allRedemptions(context: context), settings: .load())
    }

    @discardableResult
    static func add(
        title: String,
        category: Category = .need,
        points: Int = 1,
        status: Status = .upNext,
        dueDate: Date? = nil,
        tags: [String] = [],
        notes: String = "",
        context: ModelContext
    ) -> Ticket {
        let last = tickets(in: status, context: context).last?.sortIndex ?? 0
        let ticket = Ticket(
            title: title, notes: notes, category: category, points: points,
            status: status, sortIndex: last + 1, dueDate: dueDate, tags: tags
        )
        context.insert(ticket)
        save(context)
        return ticket
    }

    /// Moves a ticket to `status`, placed before `before` (or at the end of the column).
    /// Callers are responsible for the reward unlock check (see `needsUnlock`).
    static func move(_ ticket: Ticket, to status: Status, before: Ticket? = nil, context: ModelContext) {
        let column = tickets(in: status, context: context).filter { $0.id != ticket.id }
        if let before, let index = column.firstIndex(where: { $0.id == before.id }) {
            let upper = column[index].sortIndex
            let lower = index > 0 ? column[index - 1].sortIndex : upper - 2
            ticket.sortIndex = (lower + upper) / 2
        } else {
            ticket.sortIndex = (column.last?.sortIndex ?? 0) + 1
        }
        ticket.status = status
        save(context)
    }

    /// Whether moving `ticket` to `status` requires spending a reward first.
    static func needsUnlock(_ ticket: Ticket, to status: Status, context: ModelContext) -> Bool {
        status.requiresUnlock && ticket.isLocked(redemptions: allRedemptions(context: context))
    }

    /// Spends one reward of `kind`, optionally on a specific ticket.
    /// Returns false if no reward of that kind is available.
    @discardableResult
    static func redeem(_ kind: Category, on ticket: Ticket?, context: ModelContext) -> Bool {
        guard kind.isReward, engine(context: context).available(kind) > 0 else { return false }
        context.insert(Redemption(kind: kind, ticketID: ticket?.id))
        save(context)
        return true
    }

    /// Unlocks (spending a reward) if needed, then moves. Returns false if locked and unaffordable.
    @discardableResult
    static func unlockAndMove(_ ticket: Ticket, to status: Status, before: Ticket? = nil, context: ModelContext) -> Bool {
        if needsUnlock(ticket, to: status, context: context) {
            guard redeem(ticket.category, on: ticket, context: context) else { return false }
        }
        move(ticket, to: status, before: before, context: context)
        return true
    }

    /// Deleting a Want/Fun ticket that was unlocked but never finished refunds its reward.
    static func delete(_ ticket: Ticket, context: ModelContext) {
        if ticket.category.isReward, ticket.status != .done {
            let id = ticket.id
            for redemption in allRedemptions(context: context) where redemption.ticketID == id {
                context.delete(redemption)
            }
        }
        context.delete(ticket)
        save(context)
    }

    /// Moves tickets left in the removed Backlog column into Up Next, after the existing ones.
    static func migrateBacklog(context: ModelContext) {
        let legacy = Status.legacyBacklogRaw
        let descriptor = FetchDescriptor<Ticket>(
            predicate: #Predicate { $0.statusRaw == legacy },
            sortBy: [SortDescriptor(\.sortIndex)]
        )
        guard let old = try? context.fetch(descriptor), !old.isEmpty else { return }
        var next = (tickets(in: .upNext, context: context).last?.sortIndex ?? 0) + 1
        for ticket in old {
            ticket.statusRaw = Status.upNext.rawValue
            ticket.sortIndex = next
            next += 1
        }
        save(context)
    }

    static func save(_ context: ModelContext) {
        try? context.save()
        SharedStore.reloadWidgets()
    }
}
