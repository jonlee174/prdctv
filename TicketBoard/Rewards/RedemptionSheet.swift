import SwiftData
import SwiftUI

/// Spend a Want/Fun reward: pick a locked ticket of that kind to start, or spend it without one.
struct RedemptionSheet: View {
    let kind: Category

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Ticket.sortIndex) private var tickets: [Ticket]
    @Query(sort: \Redemption.redeemedAt, order: .reverse) private var redemptions: [Redemption]

    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio

    private var engine: RewardEngine {
        RewardEngine(tickets: tickets, redemptions: redemptions,
                     settings: RewardSettings(wantRatio: wantRatio, funRatio: funRatio))
    }

    private var candidates: [Ticket] {
        tickets.filter { $0.category == kind && $0.status != .done && $0.isLocked(redemptions: redemptions) }
            .sorted { ($0.status == .upNext ? 0 : 1, $0.sortIndex) < ($1.status == .upNext ? 0 : 1, $1.sortIndex) }
    }

    var body: some View {
        let available = engine.available(kind)

        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                RewardRing(kind: kind, engine: engine, lineWidth: 5).frame(width: 44, height: 44)
                VStack(alignment: .leading) {
                    Text("Redeem \(kind.label)").font(.title2.bold())
                    Text("\(available) available · \(engine.progressLabel(kind))")
                        .foregroundStyle(.secondary)
                }
            }

            if available <= 0 {
                let needed = (engine.redeemed(kind) + 1) * engine.settings.ratio(for: kind) - engine.needPointsDone
                Label("No \(kind.label) rewards yet. Complete \(needed) more need point\(needed == 1 ? "" : "s").",
                      systemImage: "lock.fill")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else if candidates.isEmpty {
                Text("No locked \(kind.label) tickets. Add one to the board, or spend the reward on something off the board.")
                    .foregroundStyle(.secondary)
            } else {
                Text("Pick a ticket to start. It moves to In Progress.")
                    .foregroundStyle(.secondary)
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(candidates) { ticket in
                            Button {
                                withAnimation {
                                    _ = TicketOps.unlockAndMove(ticket, to: .inProgress, context: context)
                                }
                                dismiss()
                            } label: {
                                TicketCardView(ticket: ticket, lock: .affordable)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 300)
            }

            if !history.isEmpty {
                Divider()
                Text("Recent").font(.headline)
                ForEach(history.prefix(5)) { r in
                    HStack {
                        Text(title(for: r))
                        Spacer()
                        Text(r.redeemedAt.formatted(.relative(presentation: .named)))
                            .foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
            }

            HStack {
                if available > 0 {
                    Button("Spend Without a Ticket") {
                        TicketOps.redeem(kind, on: nil, context: context)
                        dismiss()
                    }
                }
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private var history: [Redemption] {
        redemptions.filter { $0.kind == kind }
    }

    private func title(for redemption: Redemption) -> String {
        guard let id = redemption.ticketID else { return "Off-board reward" }
        return tickets.first { $0.id == id }?.title ?? "Deleted ticket"
    }
}
