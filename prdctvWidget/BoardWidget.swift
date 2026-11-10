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
        switch entry.layout {
        case .tags where family != .systemSmall:
            // Untagged tickets list under Miscellaneous.
            listLayout(entry.tagLanes.map { (tag: $0.tag ?? "Miscellaneous", items: $0.items) }, titled: true, showsTags: false)
        case .status where family != .systemSmall:
            listLayout(entry.statusSections, titled: entry.statusTitles, showsTags: entry.statusShowsTags)
        default:
            columnLayout
        }
    }

    /// Sections of open tickets under bold titles, the reward meter on the larger sizes.
    @ViewBuilder private func listLayout(_ sections: [(tag: String?, items: [TicketSnapshot])],
                                         titled: Bool, showsTags: Bool) -> some View {
        switch family {
        case .systemMedium:
            SectionColumns(sections: sections, titled: titled, showsTags: showsTags, columns: 1, rows: 6)
        case .systemLarge:
            VStack(alignment: .leading, spacing: 10) {
                if entry.largeShowsMeter { MeterBar(engine: entry.engine) }
                // The meter takes about two rows, so they go to tickets when it's hidden.
                SectionColumns(sections: sections, titled: titled, showsTags: showsTags,
                               columns: 1, rows: entry.largeShowsMeter ? 12 : 14)
            }
        default: // .systemExtraLarge
            VStack(alignment: .leading, spacing: 12) {
                if entry.rewardsEnabled { MeterBar(engine: entry.engine) }
                SectionColumns(sections: sections, titled: titled, showsTags: showsTags,
                               columns: 2, rows: entry.rewardsEnabled ? 12 : 14)
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

/// Sections packed into side by side columns, each under a bold title unless titles are off.
private struct SectionColumns: View {
    /// Each section's title is in `tag`, and is ignored when `titled` is off.
    let sections: [(tag: String?, items: [TicketSnapshot])]
    let titled: Bool
    let showsTags: Bool
    let columns: Int
    /// Lines per column, a title counting as one.
    let rows: Int

    var body: some View {
        let packed = TicketTags.pack(sections, columns: columns, rows: rows, headingLines: titled ? 1 : 0)
        HStack(alignment: .top, spacing: 14) {
            if packed.isEmpty {
                Text("Nothing to do").font(.caption).foregroundStyle(.tertiary)
            }
            ForEach(packed.indices, id: \.self) { index in
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(Array(packed[index].enumerated()), id: \.offset) { position, section in
                        if titled, let title = section.tag {
                            Text(title)
                                .font(.system(size: 12, weight: .bold))
                                .lineLimit(1)
                                .padding(.top, position == 0 ? 0 : 3)
                        }
                        ForEach(section.items) { ticket in
                            TicketRow(ticket: ticket, showsTag: showsTags)
                                .padding(.leading, titled ? 6 : 0)
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
                RowLayout {
                    Text(ticket.title)
                        .font(.system(size: 12, weight: ticket.category == .need ? .medium : .regular))
                        .foregroundStyle(ticket.locked ? .secondary : .primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .layoutValue(key: RowPart.self, value: .title)
                    if showsTag, let tag = ticket.tags.first {
                        TagChip(tag: tag, size: 9)
                            .layoutValue(key: RowPart.self, value: .tag)
                    }
                    if AppGroup.defaults.bool(forKey: TicketTags.widgetShowsDueDatesKey), let due = ticket.dueDate {
                        Text("Due \(DueLabel.text(for: due))")
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .foregroundStyle(DueLabel.isOverdue(due) ? .red : .secondary)
                            .lineLimit(1)
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

/// What a view is in a widget row. Anything unmarked is a fixed part like the date or points.
private enum RowPart: LayoutValueKey {
    static let defaultValue = Kind.fixed
    enum Kind { case title, tag, fixed }
}

/// A widget row. The date and points always get their full width, the tag gets up to half of what is left
/// (more when the title is short), and the title gets the rest and ends in "…".
private struct RowLayout: Layout {
    var spacing: CGFloat = 5

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let natural = sizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(sizes.count - 1, 0))
        return CGSize(width: proposal.width ?? natural, height: sizes.map(\.height).max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (subview, frame) in zip(subviews, frames(width: bounds.width, subviews: subviews)) {
            let y = bounds.minY + (bounds.height - frame.height) / 2
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: y), proposal: ProposedViewSize(frame.size))
        }
    }

    /// Frames along the row, x from 0, in subview order.
    private func frames(width: CGFloat, subviews: Subviews) -> [CGRect] {
        let ideal = subviews.map { $0.sizeThatFits(.unspecified) }
        let kinds = subviews.map { $0[RowPart.self] }
        let fixedWidth = zip(kinds, ideal).filter { $0.0 == .fixed }.reduce(0) { $0 + $1.1.width + spacing }
        let space = max(0, width - fixedWidth)
        let titleIdeal = zip(kinds, ideal).first { $0.0 == .title }?.1.width ?? 0
        let tagIdeal = zip(kinds, ideal).first { $0.0 == .tag }?.1.width
        var tagWidth: CGFloat = 0
        if let tagIdeal {
            // Half the space, or whatever a short title leaves, whichever is more.
            tagWidth = min(tagIdeal, max(space / 2, space - spacing - titleIdeal))
        }
        let titleWidth = max(0, space - (tagIdeal == nil ? 0 : tagWidth + spacing))

        var frames: [CGRect] = []
        // The tag and the fixed parts sit at the right edge, the title at the left.
        var trailingX = width - fixedWidth + spacing - (tagIdeal == nil ? 0 : tagWidth + spacing)
        for (kind, size) in zip(kinds, ideal) {
            switch kind {
            case .title:
                frames.append(CGRect(x: 0, y: 0, width: titleWidth, height: size.height))
            case .tag, .fixed:
                let w = kind == .tag ? tagWidth : size.width
                frames.append(CGRect(x: trailingX, y: 0, width: w, height: size.height))
                trailingX += w + spacing
            }
        }
        return frames
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
    { var entry = BoardEntry.sample; entry.layout = .tags; return entry }()
}

#Preview(as: .systemExtraLarge) {
    BoardWidget()
} timeline: {
    BoardEntry.sample
}
