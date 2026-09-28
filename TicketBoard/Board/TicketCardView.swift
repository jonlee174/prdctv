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

/// A ticket styled like a physical stub: neutral card, thin category accent edge,
/// perforated divider, and the points badge on the stub. Without points it's a plain card.
struct TicketCardView: View {
    let ticket: Ticket
    var lock: LockState
    var isSelected: Bool
    /// A tag left off the card because its lane heading already shows it.
    var hiddenTag: String?
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true

    private let stubWidth: CGFloat = 44

    init(ticket: Ticket, lock: LockState = .open, isSelected: Bool = false, hiddenTag: String? = nil) {
        self.ticket = ticket
        self.lock = lock
        self.isSelected = isSelected
        self.hiddenTag = hiddenTag
    }

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
                Rectangle().fill(ticket.category.color).frame(width: 4)
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
            HStack(spacing: 5) {
                Image(systemName: ticket.category.symbol)
                    .font(.system(size: 7))
                    .foregroundStyle(ticket.category.color)
                Text(ticket.category.label.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                if ticket.category.isReward {
                    Image(systemName: lock == .open ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(lock == .affordable ? ticket.category.color : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                        .opacity(lock == .open ? 0 : 1)
                }
            }

            Text(ticket.title)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(3)
                .strikethrough(ticket.status == .done, color: .secondary)

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
                }
                .font(.system(size: 10))
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
            }
        }
    }

    private var stub: some View {
        VStack(spacing: 0) {
            Text("\(ticket.points)")
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(ticket.category == .need ? ticket.category.color : .primary)
            Text(ticket.points == 1 ? "pt" : "pts")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }

    private var hasMeta: Bool {
        ticket.dueDate != nil || !shownTags.isEmpty || !ticket.notes.isEmpty
    }

    private var shownTags: [String] {
        guard let hiddenTag else { return ticket.tags }
        return ticket.tags.filter { $0.caseInsensitiveCompare(hiddenTag) != .orderedSame }
    }

    private var isOverdue: Bool {
        guard let due = ticket.dueDate, ticket.status != .done else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    private var accessibilityText: String {
        var parts = ["\(ticket.category.label) ticket", ticket.title]
        if pointsEnabled { parts.append("\(ticket.points) points") }
        parts += ticket.tags.map { "tag \($0)" }
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
