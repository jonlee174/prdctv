import SwiftUI

enum CardAction {
    case edit, advance, move(Status), points(Int), delete
}

struct ColumnView: View {
    let status: Status
    /// Already filtered and ordered for display.
    let tickets: [Ticket]
    let grouping: LaneGrouping
    /// Optional user-chosen column color (Settings → Colors).
    var tint: Color?
    let selectedID: UUID?
    let lockState: (Ticket) -> LockState
    let onSelect: (Ticket) -> Void
    let onAction: (CardAction, Ticket) -> Void
    /// A ticket ID was dropped, to be placed before the given ticket (nil = end of column).
    let onDrop: (UUID, Ticket?) -> Void
    var onAdd: (() -> Void)?
    var footer: AnyView?

    @State private var isTargeted = false
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(grouping.lanes(tickets)) { lane in
                            if grouping != .none {
                                LaneHeadingView(heading: lane.heading).padding(.top, 4)
                            }
                            cards(lane.tickets, hiding: lane.tag)
                        }
                        if let footer { footer }
                    }
                    .padding(.bottom, 40) // room to drop at the end
                }
                .scrollIndicators(.never)
                .onChange(of: selectedID) { _, id in
                    guard let id, tickets.contains(where: { $0.id == id }) else { return }
                    withAnimation { proxy.scrollTo(id) }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: Radius.medium)
                .fill(isTargeted ? AnyShapeStyle(.tint.opacity(0.10)) : AnyShapeStyle(tint?.opacity(0.10) ?? Color.primary.opacity(0.045)))
        )
        .overlay(alignment: .top) {
            if let tint {
                UnevenRoundedRectangle(topLeadingRadius: Radius.medium, topTrailingRadius: Radius.medium)
                    .fill(tint)
                    .frame(height: 3)
            }
        }
        .dropDestination(for: String.self) { items, _ in
            drop(items, before: nil)
        } isTargeted: { isTargeted = $0 }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(status.label)
                .font(.headline)
                .foregroundStyle(tint ?? .primary)
            Text("\(tickets.count)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: Radius.tiny).fill(Color.primary.opacity(0.08)))
            Spacer()
            let points = tickets.filter { $0.category == .need }.reduce(0) { $0 + $1.points }
            if pointsEnabled, points > 0 {
                Text("\(points) pts").font(.caption).foregroundStyle(.secondary)
            }
            if let onAdd {
                Button(action: onAdd) { Image(systemName: "plus") }
                    .buttonStyle(.borderless)
                    .help("New ticket in \(status.label)")
            }
        }
        .padding(.horizontal, 2)
    }

    private func cards(_ list: [Ticket], hiding tag: String?) -> some View {
        ForEach(list) { ticket in
            CardRow(
                ticket: ticket,
                hiddenTag: tag,
                lock: lockState(ticket),
                isSelected: ticket.id == selectedID,
                onSelect: { onSelect(ticket) },
                onAction: { onAction($0, ticket) },
                onDropBefore: { items in drop(items, before: ticket) }
            )
            .id(ticket.id)
        }
    }

    private func drop(_ items: [String], before: Ticket?) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
        if id == before?.id { return false }
        onDrop(id, before)
        return true
    }
}

private struct CardRow: View {
    let ticket: Ticket
    let hiddenTag: String?
    let lock: LockState
    let isSelected: Bool
    let onSelect: () -> Void
    let onAction: (CardAction) -> Void
    let onDropBefore: ([String]) -> Bool

    @State private var isTargeted = false

    var body: some View {
        TicketCardView(ticket: ticket, lock: lock, isSelected: isSelected, hiddenTag: hiddenTag)
            .overlay(alignment: .top) {
                if isTargeted {
                    Rectangle().fill(.tint).frame(height: 2).offset(y: -5)
                }
            }
            // Simultaneous so a single click selects at once instead of waiting out the double-click window.
            .onTapGesture { onSelect() }
            .simultaneousGesture(TapGesture(count: 2).onEnded { onAction(.edit) })
            .draggable(ticket.id.uuidString) {
                TicketCardView(ticket: ticket, lock: lock).frame(width: 240)
            }
            .dropDestination(for: String.self) { items, _ in
                onDropBefore(items)
            } isTargeted: { isTargeted = $0 }
            .contextMenu { menu }
    }

    @ViewBuilder private var menu: some View {
        Button("Edit…") { onAction(.edit) }
        if let next = ticket.status.next {
            Button("Move to \(next.label)") { onAction(.advance) }
        }
        Menu("Move To") {
            ForEach(Status.allCases.filter { $0 != ticket.status }) { status in
                Button(status.label) { onAction(.move(status)) }
            }
        }
        if RewardSettings.pointsEnabled() {
            Menu("Points") {
                ForEach(PointScale.values, id: \.self) { value in
                    Button {
                        onAction(.points(value))
                    } label: {
                        if value == ticket.points { Label("\(value)", systemImage: "checkmark") } else { Text("\(value)") }
                    }
                }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { onAction(.delete) }
    }
}
