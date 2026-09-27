import SwiftData
import SwiftUI

/// One column at a time: a segmented picker switches columns, swipe right advances a
/// ticket, swipe left deletes, and long-press offers move / points / edit.
struct PhoneBoardView: View {
    @Environment(PhoneModel.self) private var model
    @Environment(\.modelContext) private var context

    @Query(sort: \Ticket.sortIndex) private var tickets: [Ticket]
    @Query(sort: \Redemption.redeemedAt) private var redemptions: [Redemption]

    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    @AppStorage("doneShowsAll") private var doneShowsAll = false

    @State private var column = Status.upNext
    private var theme = ThemeColors()
    @State private var filter: Set<Category> = Set(Category.allCases)
    @State private var editTarget: EditTarget?
    @State private var pendingUnlock: PendingMove?
    @State private var blocked: Ticket?
    @State private var showHistory = false
    @State private var showImport = false

    private var engine: RewardEngine {
        RewardEngine(tickets: tickets, redemptions: redemptions,
                     settings: RewardSettings(wantRatio: wantRatio, funRatio: funRatio))
    }

    var body: some View {
        @Bindable var model = model

        NavigationStack {
            List {
                Section {
                    ForEach(visible(column)) { ticket in
                        row(ticket)
                    }
                    if column == .done, !doneShowsAll, olderDoneCount > 0 {
                        Button("\(olderDoneCount) older in History") { showHistory = true }
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }
                } header: {
                    VStack(spacing: 8) {
                        RewardMeterView(engine: engine, showsTotal: false) { model.redeemKind = $0 }
                            .padding(.horizontal, -8)
                        Picker("Column", selection: $column) {
                            ForEach(Status.allCases) { status in
                                Text(status.label).tag(status)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 6)
                    }
                    .textCase(nil)
                    .foregroundStyle(.primary)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background {
                let tint = theme.column(column)
                LinearGradient(colors: [tint.opacity(0.16), tint.opacity(0.04)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            .overlay {
                if visible(column).isEmpty {
                    ContentUnavailableView(
                        "Nothing in \(column.label)",
                        systemImage: "ticket",
                        description: Text(column == .done ? "Completed tickets show up here." : "Tap + to add a ticket.")
                    )
                    .padding(.top, 180)
                }
            }
            .navigationTitle("prdctv")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $editTarget) { target in
                NavigationStack { TicketEditorView(target: target) }
            }
            .sheet(item: $model.redeemKind) { RedemptionSheet(kind: $0).presentationDetents([.medium, .large]) }
            .sheet(isPresented: $showHistory) { HistoryView() }
            .sheet(isPresented: $showImport) { WhiteboardImportView() }
            .sheet(isPresented: $model.showQuickAdd) { PhoneQuickAddSheet() }
            .modifier(BoardDialogs(
                showRedeemPicker: $model.showRedeemPicker,
                redeemKind: $model.redeemKind,
                engine: engine,
                pendingUnlock: $pendingUnlock,
                blocked: $blocked,
                confirmUnlock: { move in
                    withAnimation {
                        _ = TicketOps.unlockAndMove(move.ticket, to: move.status, context: context)
                    }
                }
            ))
            .onChange(of: model.openTicketID, initial: true) { _, id in
                guard let id, let ticket = tickets.first(where: { $0.id == id }) else { return }
                column = ticket.status
                editTarget = .existing(ticket)
                model.openTicketID = nil
            }
        }
    }

    private func row(_ ticket: Ticket) -> some View {
        TicketCardView(ticket: ticket, lock: engine.lockState(of: ticket, redemptions: redemptions))
            .contentShape(Rectangle())
            .onTapGesture { editTarget = .existing(ticket) }
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                if let next = ticket.status.next {
                    Button { requestMove(ticket, to: next) } label: {
                        Label(next.label, systemImage: next == .done ? "checkmark" : "arrow.right")
                    }
                    .tint(next == .done ? .green : .blue)
                }
            }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    withAnimation { TicketOps.delete(ticket, context: context) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .contextMenu {
                Button { editTarget = .existing(ticket) } label: { Label("Edit", systemImage: "pencil") }
                Menu {
                    ForEach(Status.allCases.filter { $0 != ticket.status }) { status in
                        Button(status.label) { requestMove(ticket, to: status) }
                    }
                } label: {
                    Label("Move To", systemImage: "arrow.right.square")
                }
                Menu {
                    ForEach(PointScale.values, id: \.self) { value in
                        Button("\(value)") {
                            ticket.points = value
                            TicketOps.save(context)
                        }
                    }
                } label: {
                    Label("Points", systemImage: "number")
                }
                Divider()
                Button(role: .destructive) {
                    withAnimation { TicketOps.delete(ticket, context: context) }
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        // The logo is a title, not a button: no Liquid Glass capsule behind it on iOS 26+.
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .principal) { AppLogo(height: 20) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .principal) { AppLogo(height: 20) }
        }
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                ForEach(Category.allCases) { category in
                    Toggle(isOn: Binding(
                        get: { filter.contains(category) },
                        set: { on in
                            if on { filter.insert(category) } else if filter.count > 1 { filter.remove(category) }
                        }
                    )) {
                        Label(category.label, systemImage: category.symbol)
                    }
                }
            } label: {
                Image(systemName: filter.count == Category.allCases.count
                      ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Menu {
                Button { editTarget = .new(column == .done ? .upNext : column) } label: {
                    Label("New Ticket…", systemImage: "square.and.pencil")
                }
                Button { showHistory = true } label: { Label("History", systemImage: "clock.arrow.circlepath") }
                Button { showImport = true } label: { Label("Import Whiteboard Photo", systemImage: "photo") }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            Button { model.showQuickAdd = true } label: { Image(systemName: "plus") }
        }
    }

    // MARK: - Data

    private func visible(_ status: Status) -> [Ticket] {
        let list = tickets.filter { $0.status == status && filter.contains($0.category) }
        guard status == .done else { return list }
        return list
            .filter { doneShowsAll || isThisWeek($0.completedAt) }
            .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
    }

    private var olderDoneCount: Int {
        tickets.filter { $0.status == .done && !isThisWeek($0.completedAt) }.count
    }

    private func isThisWeek(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private func requestMove(_ ticket: Ticket, to status: Status) {
        switch engine.check(moving: ticket, to: status, redemptions: redemptions) {
        case .needsConfirm: pendingUnlock = PendingMove(ticket: ticket, status: status, before: nil)
        case .blocked: blocked = ticket
        case .allowed: withAnimation { TicketOps.move(ticket, to: status, context: context) }
        }
    }
}
