import SwiftUI

enum CardAction {
    case edit, advance, move(Status), points(Int), delete
}

struct ColumnView: View {
    let status: Status
    /// Already filtered and ordered for display.
    let tickets: [Ticket]
    let swimlanes: Bool
    let selectedID: UUID?
    let lockState: (Ticket) -> LockState
    let onSelect: (Ticket) -> Void
    let onAction: (CardAction, Ticket) -> Void
    /// A ticket ID was dropped, to be placed before the given ticket (nil = end of column).
    let onDrop: (UUID, Ticket?) -> Void
    var onAdd: (() -> Void)?
    var footer: AnyView?

    @State private var isTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if swimlanes {
                            ForEach(Category.allCases) { category in
                                let lane = tickets.filter { $0.category == category }
                                if !lane.isEmpty {
                                    Label(category.label, systemImage: category.symbol)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(category.color)
                                        .padding(.top, 4)
                                    cards(lane)
                                }
                            }
                        } else {
                            cards(tickets)
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
            RoundedRectangle(cornerRadius: 12)
                .fill(isTargeted ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.045))
        )
        .dropDestination(for: String.self) { items, _ in
            drop(items, before: nil)
        } isTargeted: { isTargeted = $0 }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(status.label).font(.headline)
            Text("\(tickets.count)")
                .font(.caption.monospacedDigit())
                .padding(.horizontal, 6).padding(.vertical, 1)
                .background(Capsule().fill(Color.primary.opacity(0.08)))
            Spacer()
            let points = tickets.filter { $0.category == .need }.reduce(0) { $0 + $1.points }
            if points > 0 {
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

    private func cards(_ list: [Ticket]) -> some View {
        ForEach(list) { ticket in
            CardRow(
                ticket: ticket,
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
    let lock: LockState
    let isSelected: Bool
    let onSelect: () -> Void
    let onAction: (CardAction) -> Void
    let onDropBefore: ([String]) -> Bool

    @State private var isTargeted = false

    var body: some View {
        TicketCardView(ticket: ticket, lock: lock, isSelected: isSelected)
            .overlay(alignment: .top) {
                if isTargeted {
                    Capsule().fill(Color.accentColor).frame(height: 3).offset(y: -5)
                }
            }
            .onTapGesture(count: 2) { onAction(.edit) }
            .onTapGesture { onSelect() }
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
        Menu("Points") {
            ForEach(PointScale.values, id: \.self) { value in
                Button {
                    onAction(.points(value))
                } label: {
                    if value == ticket.points { Label("\(value)", systemImage: "checkmark") } else { Text("\(value)") }
                }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { onAction(.delete) }
    }
}
