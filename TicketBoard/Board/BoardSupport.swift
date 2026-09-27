import SwiftUI

enum MoveCheck {
    case allowed
    /// Locked Want/Fun ticket with a reward available: confirm spending it.
    case needsConfirm
    /// Locked with no reward available.
    case blocked
}

extension RewardEngine {
    func check(moving ticket: Ticket, to status: Status, redemptions: [Redemption]) -> MoveCheck {
        guard status.requiresUnlock, ticket.isLocked(redemptions: redemptions) else { return .allowed }
        return available(ticket.category) > 0 ? .needsConfirm : .blocked
    }
}

/// Reward confirm/blocked dialogs shared by the Mac and iPhone boards.
struct BoardDialogs: ViewModifier {
    @Binding var showRedeemPicker: Bool
    @Binding var redeemKind: Category?
    let engine: RewardEngine
    @Binding var pendingUnlock: PendingMove?
    @Binding var blocked: Ticket?
    let confirmUnlock: (PendingMove) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Redeem which reward?", isPresented: $showRedeemPicker) {
                Button("Want (\(engine.availableWant) available)") { redeemKind = .want }
                Button("Fun (\(engine.availableFun) available)") { redeemKind = .fun }
            }
            .confirmationDialog(
                unlockTitle,
                isPresented: Binding(get: { pendingUnlock != nil }, set: { if !$0 { pendingUnlock = nil } }),
                presenting: pendingUnlock
            ) { move in
                Button("Spend 1 \(move.ticket.category.label) Reward") { confirmUnlock(move) }
                Button("Cancel", role: .cancel) {}
            } message: { move in
                Text("This spends one \(move.ticket.category.label) reward. You have \(engine.available(move.ticket.category)) available.")
            }
            .alert(
                blockedTitle,
                isPresented: Binding(get: { blocked != nil }, set: { if !$0 { blocked = nil } }),
                presenting: blocked
            ) { _ in
                Button("OK") {}
            } message: { ticket in
                Text(engine.lockedMessage(ticket.category))
            }
    }

    private var unlockTitle: String {
        pendingUnlock.map { "Start “\($0.ticket.title)”?" } ?? ""
    }

    private var blockedTitle: String {
        blocked.map { "“\($0.title)” is locked" } ?? ""
    }
}

enum EditTarget: Identifiable {
    case new(Status, dueDate: Date? = nil)
    case existing(Ticket)

    var id: String {
        switch self {
        case .new(let status, let due): "new-\(status.rawValue)-\(due?.timeIntervalSince1970 ?? 0)"
        case .existing(let ticket): ticket.id.uuidString
        }
    }
}

struct PendingMove: Identifiable {
    let id = UUID()
    let ticket: Ticket
    let status: Status
    let before: Ticket?
}

struct FilterBar: View {
    @Binding var filter: Set<Category>
    @Binding var swimlanes: Bool
    var showsSwimlanes = true

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Category.allCases) { category in
                let on = filter.contains(category)
                Button {
                    if on, filter.count > 1 { filter.remove(category) } else { filter.insert(category) }
                } label: {
                    Label(category.label, systemImage: category.symbol)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: Radius.small).fill(on ? category.color.opacity(0.18) : Color.primary.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(on ? category.color.opacity(0.6) : .clear))
                        .foregroundStyle(on ? category.color : .secondary)
                }
                .buttonStyle(.plain)
                .help(on ? "Hide \(category.label) tickets" : "Show \(category.label) tickets")
            }
            Spacer()
            if showsSwimlanes {
                Toggle("Swimlanes", isOn: $swimlanes)
                    .toggleStyle(.switch)
                    .controlSize(.small)
            }
        }
    }
}
