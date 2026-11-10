import SwiftUI

enum LockState {
    /// Need ticket, or Want/Fun ticket a reward was already spent on.
    case open
    /// Locked, but a matching reward is available to spend.
    case affordable
    /// Locked with no matching reward available.
    case locked
}

extension RewardEngine {
    func lockState(of ticket: Ticket, redemptions: [Redemption]) -> LockState {
        guard ticket.isLocked(redemptions: redemptions) else { return .open }
        return available(ticket.category) > 0 ? .affordable : .locked
    }
}

/// A ticket styled like a physical stub: neutral card, thin accent edge in the task color,
/// perforated divider, and the points badge on the stub. Without points it's a plain card.
struct TicketCardView: View {
    let ticket: Ticket
    var lock: LockState
    var isSelected: Bool
    /// Off in tag lanes, where the heading already names the tag.
    var showsTags: Bool
    /// Off in category lanes, where the heading already names the category.
    var showsCategory: Bool
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    private var coloring = TaskColoring()

    private let stubWidth: CGFloat = 44

    init(ticket: Ticket, lock: LockState = .open, isSelected: Bool = false, showsTags: Bool = true, showsCategory: Bool = true) {
        self.ticket = ticket
        self.lock = lock
        self.isSelected = isSelected
        self.showsTags = showsTags
        self.showsCategory = showsCategory
    }

    /// With rewards off every ticket is Need, so the category row says nothing.
    private var showsCategoryRow: Bool { showsCategory && rewardsEnabled }

    private var taskColor: Color { coloring.color(category: ticket.category, tags: ticket.tags) }

    private var shape: AnyShape {
        pointsEnabled ? AnyShape(TicketShape(stubWidth: stubWidth)) : AnyShape(RoundedRectangle(cornerRadius: Radius.small))
    }

    var body: some View {
        HStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 9)

            if pointsEnabled {
                Perforation()
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                    .foregroundStyle(.separator)
                    .frame(width: 1)
                    .padding(.vertical, 6)

                stub.frame(width: stubWidth)
            }
        }
        .background {
            ZStack(alignment: .leading) {
                shape.fill(Color.cardBackground)
                Rectangle().fill(taskColor).frame(width: 4)
            }
            .clipShape(shape)
        }
        .overlay {
            shape
                .stroke(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary.opacity(0.1)), lineWidth: isSelected ? 2 : 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .opacity(lock == .locked ? 0.55 : 1)
        .saturation(lock == .locked ? 0.3 : 1)
        .contentShape(shape)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            if showsCategoryRow {
                HStack(spacing: 5) {
                    Image(systemName: ticket.category.symbol)
                        .font(.system(size: 7))
                        .foregroundStyle(ticket.category.color)
                    Text(ticket.category.label.uppercased())
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.secondary)
                    if ticket.category.isReward {
                        lockIcon.opacity(lock == .open ? 0 : 1)
                    }
                }
            }

            if !showsCategoryRow, !hasMeta {
                // A title only card is as tall as one with a meta line, with the title centered.
                ZStack(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("X").font(.system(size: 13, weight: .medium))
                        Label("X", systemImage: "calendar").font(.system(size: 10))
                    }
                    .hidden()
                    titleRow
                }
            } else {
                titleRow
            }

            if hasMeta {
                FlowLayout(spacing: 6) {
                    ForEach(shownTags, id: \.self) { tag in
                        TagChip(tag: tag)
                    }
                    if let due = ticket.dueDate {
                        Label(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), systemImage: "calendar")
                            .foregroundStyle(isOverdue ? .red : .secondary)
                    }
                    if !ticket.notes.isEmpty {
                        Image(systemName: "text.alignleft").foregroundStyle(.tertiary)
                    }
                    if let rule = ticket.repeatRule {
                        Label(rule.label, systemImage: "repeat").foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 10))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            }
        }
    }

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            // Without the category row, a locked reward keeps its lock beside the title.
            if !showsCategoryRow, ticket.category.isReward, lock != .open {
                lockIcon
            }
            Text(ticket.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(3)
                .strikethrough(ticket.status == .done, color: .secondary)
        }
    }

    private var lockIcon: some View {
        Image(systemName: lock == .open ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 9))
            .foregroundStyle(lock == .affordable ? ticket.category.color : .secondary)
            .contentTransition(.symbolEffect(.replace))
    }

    private var stub: some View {
        VStack(spacing: 0) {
            Text("\(ticket.points)")
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ticket.category == .need ? taskColor : .primary)
            Text(ticket.points == 1 ? "pt" : "pts")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var hasMeta: Bool {
        ticket.dueDate != nil || !shownTags.isEmpty || !ticket.notes.isEmpty || ticket.repeatRule != nil
    }

    private var shownTags: [String] {
        showsTags ? ticket.tags : []
    }

    private var isOverdue: Bool {
        guard let due = ticket.dueDate, ticket.status != .done else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    private var accessibilityText: String {
        var parts = [rewardsEnabled ? "\(ticket.category.label) ticket" : "Ticket", ticket.title]
        if pointsEnabled { parts.append("\(ticket.points) points") }
        parts += ticket.tags.map { "tag \($0)" }
        if let rule = ticket.repeatRule { parts.append("repeats \(rule.label.lowercased())") }
        switch lock {
        case .locked: parts.append("locked")
        case .affordable: parts.append("locked, reward available")
        case .open: break
        }
        return parts.joined(separator: ", ")
    }
}

private struct Perforation: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return p
    }
}
