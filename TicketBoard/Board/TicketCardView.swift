import SwiftUI

enum LockState {
    /// Need ticket, or Want/Fun ticket a reward was already spent on.
    case open
    /// Locked, but a matching reward is available to spend.
    case affordable
    /// Locked with no matching reward available.
    case locked
}

/// A ticket styled like a physical stub: neutral card, thin category accent edge,
/// perforated divider, and the points badge on the stub.
struct TicketCardView: View {
    let ticket: Ticket
    var lock: LockState = .open
    var isSelected = false

    private let stubWidth: CGFloat = 44

    var body: some View {
        HStack(spacing: 0) {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .padding(.trailing, 8)
                .padding(.vertical, 9)

            Perforation()
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [2, 3]))
                .foregroundStyle(.separator)
                .frame(width: 1)
                .padding(.vertical, 6)

            stub.frame(width: stubWidth)
        }
        .background {
            ZStack(alignment: .leading) {
                TicketShape(stubWidth: stubWidth).fill(Color(nsColor: .textBackgroundColor))
                Rectangle().fill(ticket.category.color).frame(width: 4)
            }
            .clipShape(TicketShape(stubWidth: stubWidth))
        }
        .overlay {
            TicketShape(stubWidth: stubWidth)
                .stroke(isSelected ? Color.accentColor : Color.primary.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
        .opacity(lock == .locked ? 0.55 : 1)
        .saturation(lock == .locked ? 0.3 : 1)
        .contentShape(TicketShape(stubWidth: stubWidth))
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
                HStack(spacing: 6) {
                    if let due = ticket.dueDate {
                        Label(due.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()), systemImage: "calendar")
                            .foregroundStyle(isOverdue ? .red : .secondary)
                    }
                    ForEach(ticket.tags, id: \.self) { tag in
                        Text("#\(tag)").foregroundStyle(.secondary)
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
        ticket.dueDate != nil || !ticket.tags.isEmpty || !ticket.notes.isEmpty
    }

    private var isOverdue: Bool {
        guard let due = ticket.dueDate, ticket.status != .done else { return false }
        return due < Calendar.current.startOfDay(for: Date())
    }

    private var accessibilityText: String {
        var parts = ["\(ticket.category.label) ticket", ticket.title, "\(ticket.points) points"]
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
