import SwiftData
import SwiftUI

private struct LiveEngine: DynamicProperty {
    @Query private var tickets: [Ticket]
    @Query private var redemptions: [Redemption]
    var rewardSettings = StoredRewardSettings()

    var engine: RewardEngine {
        RewardEngine(tickets: tickets, redemptions: redemptions,
                     settings: rewardSettings.value)
    }
    var allRedemptions: [Redemption] { redemptions }
    var settings: RewardSettings { rewardSettings.value }
}

/// Menu bar icon showing available rewards, e.g. "2W · 1F".
struct MenuBarLabel: View {
    private var live = LiveEngine()
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true

    var body: some View {
        HStack(spacing: 3) {
            Image("LogoMark")
            if rewardsEnabled {
                Text(live.engine.menuBarLabel)
            }
        }
    }
}

struct MenuBarContent: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    @Query(filter: #Predicate<Ticket> { $0.statusRaw == "upNext" }, sort: \Ticket.sortIndex)
    private var allUpNext: [Ticket]
    private var live = LiveEngine()
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    var coloring = TaskColoring()

    private var upNext: [Ticket] {
        rewardsEnabled ? allUpNext : allUpNext.filter { !$0.category.isReward }
    }

    @State private var text = ""

    var body: some View {
        let engine = live.engine

        VStack(alignment: .leading, spacing: 12) {
            if rewardsEnabled {
                HStack(spacing: 14) {
                    ForEach([Category.want, .fun]) { kind in
                        HStack(spacing: 8) {
                            RewardRing(kind: kind, engine: engine, lineWidth: 4).frame(width: 34, height: 34)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(kind.label).font(.caption.weight(.semibold))
                                Text("\(engine.available(kind)) available")
                                    .font(.caption2)
                                    .foregroundStyle(engine.available(kind) > 0 ? kind.color : .secondary)
                            }
                        }
                    }
                    Spacer()
                }

                Divider()
            }

            Text("Up Next").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if upNext.isEmpty {
                Text("Nothing up next").font(.callout).foregroundStyle(.tertiary)
            }
            ForEach(upNext.prefix(3)) { ticket in
                HStack(spacing: 8) {
                    if ticket.isLocked(redemptions: live.allRedemptions) {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                            .help("Start it from the board to spend a reward")
                    } else {
                        Button {
                            withAnimation { TicketOps.move(ticket, to: .done, context: context) }
                        } label: {
                            Image(systemName: "circle").font(.body)
                        }
                        .buttonStyle(.borderless)
                        .frame(width: 18)
                        .help("Complete")
                    }
                    Image(systemName: rewardsEnabled ? ticket.category.symbol : "circle.fill")
                        .font(.system(size: rewardsEnabled ? 7 : 5))
                        .foregroundStyle(coloring.color(category: ticket.category, tags: ticket.tags))
                    Text(ticket.title).lineLimit(1)
                    Spacer()
                    if live.settings.countsPoints {
                        Text("\(ticket.points)")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            TextField("Quick add…", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            if !text.isEmpty {
                QuickAddPreview(result: QuickAddParser().parse(text))
            }

            HStack {
                Button("Open Board") {
                    openWindow(id: WindowID.board)
                    NSApp.activate(ignoringOtherApps: true)
                }
                Spacer()
                Button {
                    openSettings()
                    NSApp.activate(ignoringOtherApps: true)
                } label: { Image(systemName: "gearshape") }
                .buttonStyle(.borderless)
                .help("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: { Image(systemName: "power") }
                .buttonStyle(.borderless)
                .help("Quit prdctv")
            }
        }
        .padding(14)
        .frame(width: 320)
        .onAppear { app.refreshIfNeeded() }
    }

    private func add() {
        let r = QuickAddParser().parse(text)
        guard !r.isEmpty else { return }
        TicketOps.add(title: r.title, category: r.category, points: r.points, status: .upNext,
                      dueDate: r.dueDate, tags: r.tags, context: context)
        text = ""
    }
}
