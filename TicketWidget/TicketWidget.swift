import AppIntents
import SwiftUI
import WidgetKit

@main
struct TicketWidgetBundle: WidgetBundle {
    var body: some Widget {
        TicketBoardWidget()
    }
}

struct TicketBoardWidget: Widget {
    let kind = "TicketBoardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardProvider()) { entry in
            TicketWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("prdctv")
        .description("Your reward meter and what's up next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct TicketWidgetView: View {
    let entry: BoardEntry
    @Environment(\.widgetFamily) private var family
    private var theme = ThemeColors()

    init(entry: BoardEntry) {
        self.entry = entry
    }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallMeter(engine: entry.engine)
                .widgetURL(entry.engine.availableWant > 0 || entry.engine.availableFun > 0
                           ? DeepLink.redeem.url : nil)
        case .systemMedium:
            // Tasks only: the reward rings live on the small, large and extra-large sizes.
            TicketList(title: "Up Next", tickets: Array(entry.upNextNeed.prefix(4)), emptyText: "No need tickets up next",
                       tint: theme.column(.upNext))
                .frame(maxHeight: .infinity, alignment: .top)
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                MeterBar(engine: entry.engine)
                let inProgress = Array(entry.inProgress.prefix(3))
                let upNext = Array(entry.upNext.prefix(6 - inProgress.count))
                TicketList(title: "In Progress", tickets: inProgress, emptyText: "Nothing in progress",
                           tint: theme.column(.inProgress))
                TicketList(title: "Up Next", tickets: upNext, emptyText: "Nothing up next",
                           tint: theme.column(.upNext))
                Spacer(minLength: 0)
            }
        default: // .systemExtraLarge
            VStack(alignment: .leading, spacing: 12) {
                MeterBar(engine: entry.engine)
                HStack(alignment: .top, spacing: 14) {
                    TicketList(title: "Up Next", tickets: Array(entry.upNext.prefix(7)), emptyText: "Nothing up next",
                               tint: theme.column(.upNext))
                    TicketList(title: "In Progress", tickets: Array(entry.inProgress.prefix(7)), emptyText: "Nothing in progress",
                               tint: theme.column(.inProgress))
                    TicketList(title: "Done this week", tickets: Array(entry.doneThisWeek.prefix(7)),
                               emptyText: "Nothing done yet", isDone: true, tint: theme.column(.done))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

// MARK: - Meter

private struct SmallMeter: View {
    let engine: RewardEngine

    var body: some View {
        VStack(spacing: 10) {
            ForEach([Category.want, .fun]) { kind in
                HStack(spacing: 10) {
                    RewardRing(kind: kind, engine: engine, lineWidth: 5)
                        .widgetAccentable()
                        .frame(width: 42, height: 42)
                    AvailableCount(kind: kind, count: engine.available(kind))
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

private struct MeterBar: View {
    let engine: RewardEngine

    var body: some View {
        HStack(spacing: 16) {
            ForEach([Category.want, .fun]) { kind in
                HStack(spacing: 8) {
                    RewardRing(kind: kind, engine: engine, lineWidth: 4)
                        .widgetAccentable()
                        .frame(width: 34, height: 34)
                    AvailableCount(kind: kind, count: engine.available(kind))
                }
            }
            Spacer()
            if engine.availableWant > 0 || engine.availableFun > 0 {
                Link(destination: DeepLink.redeem.url) {
                    Label("Redeem", systemImage: "gift.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: Radius.small).strokeBorder(lineWidth: 1.5))
                }
                .widgetAccentable()
            }
        }
    }
}

private struct AvailableCount: View {
    let kind: Category
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 3) {
                Image(systemName: kind.symbol).font(.system(size: 8))
                Text(kind.label).font(.caption.weight(.semibold))
            }
            .foregroundStyle(kind.color)
            .widgetAccentable()
            Text("\(count)")
                .font(.system(size: 20, weight: count > 0 ? .heavy : .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(count > 0 ? .primary : .secondary)
            + Text(" avail").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tickets

private struct TicketList: View {
    let title: String
    let tickets: [TicketSnapshot]
    let emptyText: String
    var isDone = false
    var tint: Color?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold))
                .tracking(0.5)
                .foregroundStyle(tint ?? .secondary)
                .widgetAccentable(tint != nil)
            if tickets.isEmpty {
                Text(emptyText).font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(tickets) { ticket in
                TicketRow(ticket: ticket, isDone: isDone)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Category is conveyed by glyph shape (circle / diamond / star), not color alone,
/// so rows stay readable in the desaturated vibrant rendering mode.
private struct TicketRow: View {
    let ticket: TicketSnapshot
    var isDone = false

    var body: some View {
        HStack(spacing: 7) {
            if isDone {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.secondary)
            } else if ticket.locked {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            } else {
                Button(intent: CompleteTicketIntent(id: ticket.id)) {
                    Image(systemName: "circle")
                        .font(.system(size: 14, weight: .semibold))
                }
                .buttonStyle(.plain)
                .widgetAccentable()
                .frame(width: 16)
            }

            Link(destination: DeepLink.ticket(ticket.id).url) {
                HStack(spacing: 5) {
                    Image(systemName: ticket.category.symbol)
                        .font(.system(size: 7))
                        .foregroundStyle(ticket.category.color)
                        .widgetAccentable()
                    Text(ticket.title)
                        .font(.system(size: 12, weight: ticket.category == .need ? .medium : .regular))
                        .strikethrough(isDone)
                        .foregroundStyle(ticket.locked || isDone ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Text("\(ticket.points)")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview(as: .systemMedium) {
    TicketBoardWidget()
} timeline: {
    BoardEntry.sample
}

#Preview(as: .systemExtraLarge) {
    TicketBoardWidget()
} timeline: {
    BoardEntry.sample
}
