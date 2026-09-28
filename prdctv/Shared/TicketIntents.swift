import AppIntents
import Foundation
import SwiftData

/// Marks a ticket done. Used by the widget's interactive complete buttons.
struct CompleteTicketIntent: AppIntent {
    static var title: LocalizedStringResource = "Complete Ticket"
    static var description = IntentDescription("Moves a ticket to Done.")
    static var isDiscoverable = false

    @Parameter(title: "Ticket ID")
    var ticketID: String

    init() {}

    init(id: UUID) {
        self.ticketID = id.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let id = UUID(uuidString: ticketID) else { return .result() }
        // Fresh container each run so we never act on rows cached before the app's last write.
        let context = ModelContext(SharedStore.makeContainer())
        let descriptor = FetchDescriptor<Ticket>(predicate: #Predicate { $0.id == id })
        guard let ticket = try context.fetch(descriptor).first, ticket.status != .done else {
            return .result()
        }
        // Locked Want/Fun tickets must be started (redeemed) in the app first.
        guard !TicketOps.needsUnlock(ticket, to: .done, context: context) else { return .result() }
        TicketOps.move(ticket, to: .done, context: context)
        SharedStore.markWidgetWrite()
        return .result()
    }
}
