import AppIntents
import SwiftUI
import WidgetKit

@main
struct PrdctvWidgetBundle: WidgetBundle {
    var body: some Widget {
        BoardWidget()
    }
}

struct BoardWidget: Widget {
    // The original name, kept because placed widgets are stored under it.
    let kind = "TicketBoardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BoardProvider()) { entry in
            BoardWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("prdctv")
        .description("Your reward meter and what's up next.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
    }
}

struct BoardWidgetView: View {
    let entry: BoardEntry
    @Environment(\.widgetFamily) private var family
    private var theme = ThemeColors()

    init(entry: BoardEntry) {
        self.entry = entry
    }

    var body: some View {
        if entry.listByTag, family != .systemSmall {
            tagLayout
        } else {
            columnLayout
        }
    }

    /// Bold tag titles with their open tickets underneath, the reward meter on the larger sizes.
    @ViewBuilder private var tagLayout: some View {
        switch family {
        case .systemMedium:
            TagColumns(lanes: entry.tagLanes, columns: 1, rows: 6)
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                if entry.largeShowsMeter { MeterBar(engine: entry.engine) }
                // The meter takes about two rows, so they go to tickets when it's hidden.
                TagColumns(lanes: entry.tagLanes, columns: 1, rows: entry.largeShowsMeter ? 12 : 14)
            }
        default: // .systemExtraLarge
            VStack(alignment: .leading, spacing: 12) {
                if entry.rewardsEnabled { MeterBar(engine: entry.engine) }
                TagColumns(lanes: entry.tagLanes, columns: 3, rows: entry.rewardsEnabled ? 12 : 14)
            }
        }
    }

    @ViewBuilder private var columnLayout: some View {
        switch family {
        case .systemSmall:
            if entry.rewardsEnabled {
                SmallMeter(engine: entry.engine)
                    .widgetURL(entry.engine.availableWant > 0 || entry.engine.availableFun > 0
                               ? DeepLink.redeem.url : nil)
            } else {
                // Only the meter fits here, so without rewards the small size lists Up Next.
                TicketList(title: "Up Next", tickets: Array(entry.upNext.prefix(4)), emptyText: "Nothing up next",
                           tint: theme.column(.upNext), showsTags: false)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        case .systemMedium:
            // Tasks only. The reward rings live on the small, large and extra-large sizes.
            TicketList(title: "Up Next", tickets: Array(entry.upNextNeed.prefix(4)), emptyText: "No need tickets up next",
                       tint: theme.column(.upNext))
                .frame(maxHeight: .infinity, alignment: .top)
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                if entry.largeShowsMeter { MeterBar(engine: entry.engine) }
                let inProgress = Array(entry.inProgress.prefix(3))
                let upNext = Array(entry.upNext.prefix((entry.largeShowsMeter ? 6 : 8) - inProgress.count))
                TicketList(title: "In Progress", tickets: inProgress, emptyText: "Nothing in progress",
                           tint: theme.column(.inProgress))
                TicketList(title: "Up Next", tickets: upNext, emptyText: "Nothing up next",
                           tint: theme.column(.upNext))
                Spacer(minLength: 0)
            }
        default: // .systemExtraLarge
            VStack(alignment: .leading, spacing: 12) {
                if entry.rewardsEnabled { MeterBar(engine: entry.engine) }
                HStack(alignment: .top, spacing: 14) {
                    TicketList(title: "Up Next", tickets: Array(entry.upNext.prefix(7)), emptyText: "Nothing up next",
                               tint: theme.column(.upNext))
                    TicketList(title: "In Progress", tickets: Array(entry.inProgress.prefix(7)), emptyText: "Nothing in progress",
                               tint: theme.column(.inProgress))
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
            Text(kind.label)
                .font(.caption.weight(.semibold))
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
    var tint: Color?
    var showsTags = true

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
                TicketRow(ticket: ticket, showsTag: showsTags)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Tag lanes packed into side by side columns, each a bold title over its tickets.
private struct TagColumns: View {
    let lanes: [(tag: String?, items: [TicketSnapshot])]
    let columns: Int
    /// Lines per column, a title counting as one.
    let rows: Int

    var body: some View {
        let packed = TicketTags.pack(lanes, columns: columns, rows: rows)
        HStack(alignment: .top, spacing: 14) {
            if packed.isEmpty {
                Text("Nothing to do").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(packed.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(packed[index], id: \.tag) { lane in
                        Text(lane.tag ?? "Miscellaneous")
                            .font(.system(size: 12, weight: .bold))
                            .lineLimit(1)
                            .padding(.top, lane.tag == packed[index].first?.tag ? 0 : 3)
                        ForEach(lane.items) { ticket in
                            TicketRow(ticket: ticket, showsTag: false)
                                .padding(.leading, 6)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // Keep columns their full width when fewer are filled.
            ForEach(packed.count..<max(columns, packed.count), id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

/// One open ticket, with no category icon since the widget never needs it.
private struct TicketRow: View {
    let ticket: TicketSnapshot
    var showsTag = true

    var body: some View {
        HStack(spacing: 7) {
            if ticket.locked {
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
                    Text(ticket.title)
                        .font(.system(size: 12, weight: ticket.category == .need ? .medium : .regular))
                        .foregroundStyle(ticket.locked ? .secondary : .primary)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    if showsTag, let tag = ticket.tags.first {
                        // The title truncates before the tag, so the class stays readable.
                        TagChip(tag: tag, size: 9)
                            .frame(maxWidth: 90, alignment: .trailing)
                            .layoutPriority(1)
                    }
                    if RewardSettings.pointsEnabled() {
                        Text("\(ticket.points)")
                            .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

#Preview(as: .systemMedium) {
    BoardWidget()
} timeline: {
    BoardEntry.sample
}

#Preview("By tag", as: .systemLarge) {
    BoardWidget()
} timeline: {
    { var entry = BoardEntry.sample; entry.listByTag = true; return entry }()
}

#Preview(as: .systemExtraLarge) {
    BoardWidget()
} timeline: {
    BoardEntry.sample
}
