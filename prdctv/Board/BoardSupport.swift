import SwiftUI

enum MoveCheck {
    case allowed
    /// Locked Want/Fun ticket with a reward available: confirm spending it.
    case needsConfirm
    /// Locked with no reward available.
    case blocked
}

extension RewardEngine {
    func check(moving ticket: Ticket, to status: Status, redemptions: [Redemption]) -> MoveCheck {
        guard status.requiresUnlock, ticket.isLocked(redemptions: redemptions) else { return .allowed }
        return available(ticket.category) > 0 ? .needsConfirm : .blocked
    }
}

/// Reward confirm/blocked dialogs shared by the Mac and iPhone boards.
struct BoardDialogs: ViewModifier {
    @Binding var showRedeemPicker: Bool
    @Binding var redeemKind: Category?
    let engine: RewardEngine
    @Binding var pendingUnlock: PendingMove?
    @Binding var blocked: Ticket?
    let confirmUnlock: (PendingMove) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Redeem which reward?", isPresented: $showRedeemPicker) {
                Button("Want (\(engine.availableWant) available)") { redeemKind = .want }
                Button("Fun (\(engine.availableFun) available)") { redeemKind = .fun }
            }
            .confirmationDialog(
                unlockTitle,
                isPresented: Binding(get: { pendingUnlock != nil }, set: { if !$0 { pendingUnlock = nil } }),
                presenting: pendingUnlock
            ) { move in
                Button("Spend 1 \(move.ticket.category.label) Reward") { confirmUnlock(move) }
                Button("Cancel", role: .cancel) {}
            } message: { move in
                Text("This spends one \(move.ticket.category.label) reward. You have \(engine.available(move.ticket.category)) available.")
            }
            .alert(
                blockedTitle,
                isPresented: Binding(get: { blocked != nil }, set: { if !$0 { blocked = nil } }),
                presenting: blocked
            ) { _ in
                Button("OK") {}
            } message: { ticket in
                Text(engine.lockedMessage(ticket.category))
            }
    }

    private var unlockTitle: String {
        pendingUnlock.map { "Start “\($0.ticket.title)”?" } ?? ""
    }

    private var blockedTitle: String {
        blocked.map { "“\($0.title)” is locked" } ?? ""
    }
}

enum EditTarget: Identifiable {
    case new(Status, dueDate: Date? = nil)
    case existing(Ticket)

    var id: String {
        switch self {
        case .new(let status, let due): "new-\(status.rawValue)-\(due?.timeIntervalSince1970 ?? 0)"
        case .existing(let ticket): ticket.id.uuidString
        }
    }
}

struct PendingMove: Identifiable {
    let id = UUID()
    let ticket: Ticket
    let status: Status
    let before: Ticket?
}

/// How each column splits into lanes.
enum LaneGrouping: String, CaseIterable, Identifiable {
    case none, category, tag

    static let storageKey = "laneGrouping"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: "None"
        case .category: "Category"
        case .tag: "Tag"
        }
    }

    var menuTitle: String {
        switch self {
        case .none: "No Lanes"
        case .category: "Lanes by Category"
        case .tag: "Lanes by Tag"
        }
    }

    /// Splits tickets into lanes. Tag lanes follow `tagOrder`, other lanes keep the board order.
    func lanes(_ tickets: [Ticket], tagOrder: TagLaneOrder = TagLaneOrder()) -> [Lane] {
        switch self {
        case .none:
            return [Lane(heading: .none, tickets: tickets)]
        case .category:
            return Category.allCases.compactMap { category in
                let list = tickets.filter { $0.category == category }
                return list.isEmpty ? nil : Lane(heading: .category(category), tickets: list)
            }
        case .tag:
            // A ticket with several tags goes in its first tag's lane, like the widget.
            return TicketTags.lanes(tickets, tags: \.tags, dueDate: \.dueDate, order: tagOrder).map { lane in
                Lane(heading: lane.tag.map { .tag($0) } ?? .untagged, tickets: lane.items)
            }
        }
    }
}

/// A run of tickets under one heading inside a column.
struct Lane: Identifiable {
    enum Heading {
        case none, category(Category), tag(String), untagged
    }

    let heading: Heading
    let tickets: [Ticket]

    var id: String {
        switch heading {
        case .none: "all"
        case .category(let category): "category-\(category.rawValue)"
        case .tag(let tag): "tag-\(tag.lowercased())"
        case .untagged: "untagged"
        }
    }
}

/// The heading drawn above a lane.
struct LaneHeadingView: View {
    let heading: Lane.Heading
    @AppStorage(TicketTags.plainLaneTitlesKey, store: AppGroup.defaults) private var plainTagTitles = false

    init(heading: Lane.Heading) {
        self.heading = heading
    }

    var body: some View {
        switch heading {
        case .none:
            EmptyView()
        case .category(let category):
            Label(category.label, systemImage: category.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(category.color)
        case .tag(let tag):
            if plainTagTitles {
                Text(tag).font(.subheadline.weight(.bold))
            } else {
                TagChip(tag: tag, size: 11)
            }
        case .untagged:
            Text("No tag")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

struct FilterBar: View {
    @Binding var filter: Set<Category>
    @Binding var grouping: LaneGrouping
    @Binding var tag: String?
    let tags: [String]
    var categories: [Category] = Category.allCases
    var showsGrouping = true

    var body: some View {
        HStack(spacing: 8) {
            // A lone Need chip filters nothing, so chips only show with rewards on.
            ForEach(categories.count > 1 ? categories : []) { category in
                let on = filter.contains(category)
                Button {
                    if on, filter.count > 1 { filter.remove(category) } else { filter.insert(category) }
                } label: {
                    Label(category.label, systemImage: category.symbol)
                        .font(.callout.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: Radius.small).fill(on ? category.color.opacity(0.18) : Color.primary.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: Radius.small).stroke(on ? category.color.opacity(0.6) : .clear))
                        .foregroundStyle(on ? category.color : .secondary)
                }
                .buttonStyle(.plain)
                .help(on ? "Hide \(category.label) tickets" : "Show \(category.label) tickets")
            }
            TagFilterPicker(tag: $tag, tags: tags)
                .fixedSize()
            Spacer()
            if showsGrouping {
                LaneMenu(grouping: $grouping)
                    .fixedSize()
                    .help("Group each column by category or tag")
            }
        }
    }
}

/// Picks the lane grouping, plus plain titles when grouping by tag.
struct LaneMenu: View {
    @Binding var grouping: LaneGrouping
    @AppStorage(TicketTags.plainLaneTitlesKey, store: AppGroup.defaults) private var plainTagTitles = false

    init(grouping: Binding<LaneGrouping>) {
        _grouping = grouping
    }

    var body: some View {
        Menu {
            Picker("Lanes", selection: $grouping) {
                ForEach(LaneGrouping.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.inline)
            if grouping == .tag {
                Divider()
                Toggle("Plain Tag Titles", isOn: $plainTagTitles)
            }
        } label: {
            Label(grouping.menuTitle, systemImage: "rectangle.grid.1x2")
        }
    }
}

/// Picks one tag to show, or all tickets.
struct TagFilterPicker: View {
    @Binding var tag: String?
    let tags: [String]

    var body: some View {
        Picker(selection: $tag) {
            Label("All Tags", systemImage: "tag").tag(String?.none)
            if !tags.isEmpty { Divider() }
            ForEach(tags, id: \.self) { Text($0).tag(Optional($0)) }
        } label: {
            Label("Tag", systemImage: "tag")
        }
        .pickerStyle(.menu)
        .disabled(tags.isEmpty)
        .help("Show only tickets with one tag")
    }
}

/// The tag lane order from Settings, read live so lanes reorder when it changes.
struct StoredTagLaneOrder: DynamicProperty {
    @AppStorage(TicketTags.tagOrderKey, store: AppGroup.defaults) private var tagsRaw = TagLaneOrder.Tags.custom.rawValue
    @AppStorage(TicketTags.tagTaskOrderKey, store: AppGroup.defaults) private var tasksRaw = TagLaneOrder.Tasks.board.rawValue
    @AppStorage(TicketTags.tagPriorityKey, store: AppGroup.defaults) private var priorityRaw = ""

    var value: TagLaneOrder { TagLaneOrder(tagsRaw: tagsRaw, tasksRaw: tasksRaw, priorityRaw: priorityRaw) }
}
