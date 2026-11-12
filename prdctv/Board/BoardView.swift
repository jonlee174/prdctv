import SwiftData
import SwiftUI

struct BoardView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow

    @Query(sort: \Ticket.sortIndex) private var tickets: [Ticket]
    @Query(sort: \Redemption.redeemedAt) private var redemptions: [Redemption]

    var rewardSettings = StoredRewardSettings()
    var storedTagOrder = StoredTagLaneOrder()
    @AppStorage(LaneGrouping.storageKey) private var grouping = LaneGrouping.none
    @AppStorage("doneShowsAll") private var doneShowsAll = false
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true

    @State private var filter: Set<Category> = Set(Category.allCases)
    @State private var tagFilter: String?
    private var theme = ThemeColors()
    @State private var editTarget: EditTarget?
    @State private var pendingUnlock: PendingMove?
    @State private var blocked: Ticket?
    @State private var showHistory = false
    @FocusState private var boardFocused: Bool

    private var engine: RewardEngine {
        RewardEngine(tickets: tickets, redemptions: redemptions,
                     settings: rewardSettings.value)
    }

    var body: some View {
        VStack(spacing: 0) {
            if rewardsEnabled {
                RewardMeterView(engine: engine) { app.redeemKind = $0 }
            }
            FilterBar(filter: $filter, grouping: $grouping, tag: $tagFilter, tags: tags,
                      categories: Category.shown(rewardsEnabled: rewardsEnabled),
                      showsGrouping: app.boardMode == .board)
                .padding(.top, rewardsEnabled ? 0 : 12)
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            switch app.boardMode {
            case .board:
                HStack(alignment: .top, spacing: 12) {
                    ForEach(Status.allCases) { column($0) }
                }
                .padding([.horizontal, .bottom], 16)
            case .calendar:
                TicketCalendarView(filter: shownCategories, tag: activeTag)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .celebratesCompletions()
        .focusable()
        .focusEffectDisabled()
        .focused($boardFocused)
        .onKeyPress(phases: .down, action: handleKey)
        .onAppear { boardFocused = true }
        .toolbar { toolbar }
        .modifier(sheets)
        .modifier(dialogs)
        .onChange(of: app.newTicketRequest) { _, status in
            guard let status else { return }
            editTarget = .new(status)
            app.newTicketRequest = nil
        }
    }

    private func column(_ status: Status) -> ColumnView {
        let onAdd: (() -> Void)? = status == .done ? nil : { editTarget = .new(status) }
        let footer: AnyView? = status == .done ? AnyView(historyFooter) : nil
        return ColumnView(
            status: status,
            tickets: visible(status),
            grouping: grouping,
            tagOrder: storedTagOrder.value,
            tint: theme.column(status),
            selectedID: app.selectedTicketID,
            lockState: lockState,
            onSelect: select,
            onAction: perform,
            onDrop: { id, before in dropTicket(id, into: status, before: before) },
            onAdd: onAdd,
            footer: footer
        )
    }

    private func dropTicket(_ id: UUID, into status: Status, before: Ticket?) {
        guard let ticket = tickets.first(where: { $0.id == id }) else { return }
        requestMove(ticket, to: status, before: before)
    }

    private var sheets: BoardSheets {
        BoardSheets(app: app, editTarget: $editTarget, showHistory: $showHistory)
    }

    private var dialogs: BoardDialogs {
        @Bindable var app = app
        return BoardDialogs(
            showRedeemPicker: $app.showRedeemPicker,
            redeemKind: $app.redeemKind,
            engine: engine,
            pendingUnlock: $pendingUnlock,
            blocked: $blocked,
            confirmUnlock: { move in
                withAnimation(.snappy) {
                    _ = TicketOps.unlockAndMove(move.ticket, to: move.status, before: move.before, context: context)
                }
            }
        )
    }

    // MARK: - Data

    private func visible(_ status: Status) -> [Ticket] {
        let list = tickets.filter {
            $0.status == status && shownCategories.contains($0.category) && TicketTags.matches($0.tags, activeTag)
        }
        guard status == .done else { return list }
        return list
            .filter { doneShowsAll || isThisWeek($0.completedAt) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    /// Tickets in on-screen order per column, after lanes regroup them.
    private var grid: [[Ticket]] {
        Status.allCases.map { grouping.lanes(visible($0), tagOrder: storedTagOrder.value).flatMap(\.tickets) }
    }

    /// The category filter, minus Want and Fun while rewards are off.
    private var shownCategories: Set<Category> {
        filter.intersection(Category.shown(rewardsEnabled: rewardsEnabled))
    }

    /// Tags in use, alphabetical.
    private var tags: [String] {
        TicketTags.sortedTags(in: tickets.map(\.tags))
    }

    /// The tag filter, dropped once no ticket carries that tag.
    private var activeTag: String? {
        tagFilter.flatMap { tag in tags.contains(tag) ? tag : nil }
    }

    private var olderDoneCount: Int {
        tickets.filter { $0.status == .done && !isThisWeek($0.completedAt) }.count
    }

    private func isThisWeek(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private func lockState(_ ticket: Ticket) -> LockState {
        engine.lockState(of: ticket, redemptions: redemptions)
    }

    @ViewBuilder private var historyFooter: some View {
        if !doneShowsAll, olderDoneCount > 0 {
            Button("\(olderDoneCount) older in History") { showHistory = true }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .font(.caption)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    // MARK: - Actions

    private func select(_ ticket: Ticket) {
        app.selectedTicketID = ticket.id
        boardFocused = true
    }

    private func requestMove(_ ticket: Ticket, to status: Status, before: Ticket? = nil) {
        switch engine.check(moving: ticket, to: status, redemptions: redemptions) {
        case .needsConfirm:
            pendingUnlock = PendingMove(ticket: ticket, status: status, before: before)
        case .blocked:
            blocked = ticket
        case .allowed:
            withAnimation(.snappy) {
                TicketOps.move(ticket, to: status, before: before, context: context)
            }
        }
    }

    private func perform(_ action: CardAction, on ticket: Ticket) {
        switch action {
        case .edit:
            editTarget = .existing(ticket)
        case .advance:
            if let next = ticket.status.next { requestMove(ticket, to: next) }
        case .move(let status):
            requestMove(ticket, to: status)
        case .hold:
            withAnimation { TicketOps.setHold(ticket, !ticket.onHold, context: context) }
        case .points(let value):
            ticket.points = value
            TicketOps.save(context)
        case .delete:
            if app.selectedTicketID == ticket.id { app.selectedTicketID = nil }
            withAnimation { TicketOps.delete(ticket, context: context) }
        }
    }

    // MARK: - Keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard app.boardMode == .board else { return .ignored }
        let selected = tickets.first { $0.id == app.selectedTicketID }

        if press.modifiers.contains(.command) {
            if press.key == .delete, let selected {
                perform(.delete, on: selected)
                return .handled
            }
            return .ignored
        }
        guard press.modifiers.isDisjoint(with: [.option, .control, .shift]) else { return .ignored }

        switch press.key {
        case .upArrow: navigate(dx: 0, dy: -1); return .handled
        case .downArrow: navigate(dx: 0, dy: 1); return .handled
        case .leftArrow: navigate(dx: -1, dy: 0); return .handled
        case .rightArrow: navigate(dx: 1, dy: 0); return .handled
        case .space:
            if let selected { perform(.advance, on: selected) }
            return .handled
        case .return:
            if let selected { perform(.edit, on: selected) }
            return .handled
        case .escape:
            app.selectedTicketID = nil
            return .handled
        default: break
        }

        switch press.characters.lowercased() {
        case "n":
            editTarget = .new(.upNext)
            return .handled
        case "h":
            if let selected, selected.status != .done { perform(.hold, on: selected) }
            return .handled
        case "1", "2", "3", "4", "5":
            guard rewardSettings.value.countsPoints, let selected, let n = Int(press.characters) else { return .ignored }
            perform(.points(PointScale.values[n - 1]), on: selected)
            return .handled
        default:
            return .ignored
        }
    }

    private func navigate(dx: Int, dy: Int) {
        let grid = grid
        guard let id = app.selectedTicketID,
              let col = grid.firstIndex(where: { $0.contains { $0.id == id } }),
              let row = grid[col].firstIndex(where: { $0.id == id })
        else {
            app.selectedTicketID = grid.first(where: { !$0.isEmpty })?.first?.id
            return
        }
        if dy != 0 {
            let newRow = min(max(row + dy, 0), grid[col].count - 1)
            app.selectedTicketID = grid[col][newRow].id
            return
        }
        var newCol = col + dx
        while grid.indices.contains(newCol), grid[newCol].isEmpty { newCol += dx }
        guard grid.indices.contains(newCol) else { return }
        app.selectedTicketID = grid[newCol][min(row, grid[newCol].count - 1)].id
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        // The logo is a title, not a button: no Liquid Glass capsule behind it on macOS 26+.
        if #available(macOS 26.0, *) {
            ToolbarItem(placement: .navigation) { AppLogo(height: 20) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) { AppLogo(height: 20) }
        }
        ToolbarItem(placement: .principal) {
            Picker("View", selection: Binding(get: { app.boardMode }, set: { app.boardMode = $0 })) {
                Label("Board", systemImage: "rectangle.split.3x1").tag(BoardMode.board)
                Label("Calendar", systemImage: "calendar").tag(BoardMode.calendar)
            }
            .pickerStyle(.segmented)
            .help("Switch between board and calendar (⌘1 / ⌘2)")
        }
        ToolbarItemGroup {
            Button { editTarget = .new(.upNext) } label: {
                Label("New Ticket", systemImage: "plus")
            }
            .help("New ticket (N)")
            Button { app.quickAdd.show() } label: {
                Label("Quick Add", systemImage: "bolt")
            }
            .help("Quick add (⌥Space)")
            Button { showHistory = true } label: {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
            Button { openWindow(id: WindowID.stats) } label: {
                Label("Stats", systemImage: "chart.bar")
            }
            Toggle(isOn: $doneShowsAll) {
                Label("Show All Done", systemImage: "checkmark.circle")
            }
            .help("Show all completed tickets in Done, not just this week")
        }
    }
}

private struct BoardSheets: ViewModifier {
    @Bindable var app: AppModel
    @Binding var editTarget: EditTarget?
    @Binding var showHistory: Bool

    func body(content: Content) -> some View {
        content
            .sheet(item: $editTarget) { TicketEditorView(target: $0) }
            .sheet(item: $app.redeemKind) { RedemptionSheet(kind: $0) }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $app.showImport) { WhiteboardImportView() }
    }
}
