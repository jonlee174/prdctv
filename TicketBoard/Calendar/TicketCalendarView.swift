import SwiftData
import SwiftUI

/// Self-contained calendar of tickets by due date. Pick a day to see its tickets, add a
/// ticket on that day, or drag tickets between days (and from Unscheduled) to reschedule.
struct TicketCalendarView: View {
    /// Categories to show; the Mac board passes its filter chips.
    var filter: Set<Category> = Set(Category.allCases)

    @Environment(\.modelContext) private var context
    @Query(sort: \Ticket.sortIndex) private var tickets: [Ticket]
    @Query private var redemptions: [Redemption]
    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    private var theme = ThemeColors()

    @State private var grid = MonthGrid(containing: Date())
    @State private var selectedDay = Calendar.current.startOfDay(for: Date())
    @State private var editTarget: EditTarget?

    init(filter: Set<Category> = Set(Category.allCases)) {
        self.filter = filter
    }

    private var calendar: Calendar { .current }
    private var accent: Color { theme.calendar }

    private var engine: RewardEngine {
        RewardEngine(tickets: tickets, redemptions: redemptions,
                     settings: RewardSettings(wantRatio: wantRatio, funRatio: funRatio))
    }

    private var byDay: [Date: [Ticket]] {
        Dictionary(grouping: tickets.filter { $0.dueDate != nil && filter.contains($0.category) }) {
            calendar.startOfDay(for: $0.dueDate!)
        }
        .mapValues { $0.sorted { ($0.status == .done ? 1 : 0, $0.sortIndex) < ($1.status == .done ? 1 : 0, $1.sortIndex) } }
    }

    private var unscheduled: [Ticket] {
        tickets.filter { $0.dueDate == nil && $0.status != .done && filter.contains($0.category) }
    }

    var body: some View {
        Group {
            #if os(macOS)
            HStack(spacing: 0) {
                month(compact: false)
                    .padding([.leading, .bottom], 16)
                    .padding(.trailing, 12)
                Divider()
                dayPanel
                    .frame(width: 300)
            }
            #else
            ScrollView {
                VStack(spacing: 16) {
                    month(compact: true)
                    dayPanel
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            #endif
        }
        .sheet(item: $editTarget) { TicketEditorView(target: $0) }
    }

    // MARK: - Month

    private func month(compact: Bool) -> some View {
        let days = byDay
        return VStack(spacing: 8) {
            header
            HStack(spacing: 0) {
                ForEach(grid.weekdaySymbols, id: \.self) { symbol in
                    Text(compact ? String(symbol.prefix(1)) : symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            VStack(spacing: 0) {
                ForEach(grid.weeks, id: \.first) { week in
                    HStack(spacing: 0) {
                        ForEach(week, id: \.self) { day in
                            DayCell(
                                day: day,
                                inMonth: grid.contains(day),
                                isToday: calendar.isDateInToday(day),
                                isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                                tickets: days[day] ?? [],
                                accent: accent,
                                compact: compact,
                                onSelect: { select(day) },
                                onDrop: { reschedule($0, to: day) }
                            )
                        }
                    }
                    .frame(maxHeight: compact ? nil : .infinity)
                }
            }
            .background(RoundedRectangle(cornerRadius: Radius.medium).fill(Color.primary.opacity(compact ? 0 : 0.03)))
            .clipShape(RoundedRectangle(cornerRadius: Radius.medium))
            .gesture(DragGesture(minimumDistance: 40).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                withAnimation(.snappy) { grid = grid.adding(months: value.translation.width < 0 ? 1 : -1) }
            })
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text(grid.monthStart.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
                .foregroundStyle(theme.calendar)
                .contentTransition(.numericText())
            Spacer()
            Button("Today") {
                withAnimation(.snappy) { select(calendar.startOfDay(for: Date())) }
            }
            .keyboardShortcut("t", modifiers: .command)
            Button { withAnimation(.snappy) { grid = grid.adding(months: -1) } } label: {
                Image(systemName: "chevron.left")
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .help("Previous month")
            Button { withAnimation(.snappy) { grid = grid.adding(months: 1) } } label: {
                Image(systemName: "chevron.right")
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .help("Next month")
        }
        .buttonStyle(.borderless)
        .tint(accent)
        .padding(.top, 4)
    }

    // MARK: - Selected day

    private var dayPanel: some View {
        let dayTickets = byDay[selectedDay] ?? []
        let open = dayTickets.filter { $0.status != .done }.count
        let isPast = selectedDay < calendar.startOfDay(for: Date())

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedDay.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.title3.bold())
                    Text(dayTickets.isEmpty ? "Nothing due" : "\(open) open · \(dayTickets.count - open) done")
                        .font(.subheadline)
                        .foregroundStyle(isPast && open > 0 ? .red : .secondary)
                }
                Spacer()
                Button { editTarget = .new(.upNext, dueDate: selectedDay) } label: {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .tint(accent)
                .help("New ticket due this day")
            }

            ForEach(dayTickets) { ticket in
                TicketCardView(ticket: ticket, lock: engine.lockState(of: ticket, redemptions: redemptions))
                    .onTapGesture { editTarget = .existing(ticket) }
                    .draggable(ticket.id.uuidString)
                    .contextMenu {
                        Button("Edit…") { editTarget = .existing(ticket) }
                        Button("Move to Tomorrow") { reschedule(ticket.id, to: dayAfter(selectedDay)) }
                        Button("Remove Due Date") { setDue(ticket, nil) }
                    }
            }

            if !unscheduled.isEmpty {
                Divider().padding(.vertical, 4)
                Text("Unscheduled").font(.headline)
                #if os(macOS)
                Text("Drag onto a day, or use + to schedule on the selected day.")
                    .font(.caption).foregroundStyle(.secondary)
                #endif
                ForEach(unscheduled) { ticket in
                    HStack(spacing: 8) {
                        Image(systemName: ticket.category.symbol)
                            .font(.system(size: 8))
                            .foregroundStyle(ticket.category.color)
                        Text(ticket.title).lineLimit(1)
                        Spacer()
                        Button { setDue(ticket, selectedDay) } label: { Image(systemName: "plus.circle") }
                            .buttonStyle(.borderless)
                            .tint(accent)
                            .help("Schedule on the selected day")
                    }
                    .font(.callout)
                    .contentShape(Rectangle())
                    .draggable(ticket.id.uuidString)
                }
            }
        }
        #if os(macOS)
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .scrollableIfNeeded()
        #endif
    }

    // MARK: - Actions

    private func select(_ day: Date) {
        selectedDay = calendar.startOfDay(for: day)
        if !grid.contains(day) { grid = MonthGrid(containing: day) }
    }

    private func dayAfter(_ day: Date) -> Date {
        calendar.date(byAdding: .day, value: 1, to: day)!
    }

    private func reschedule(_ id: UUID, to day: Date) {
        guard let ticket = tickets.first(where: { $0.id == id }) else { return }
        withAnimation(.snappy) { setDue(ticket, day) }
    }

    private func setDue(_ ticket: Ticket, _ day: Date?) {
        ticket.dueDate = day.map { calendar.startOfDay(for: $0) }
        TicketOps.save(context)
    }
}

private struct DayCell: View {
    let day: Date
    let inMonth: Bool
    let isToday: Bool
    let isSelected: Bool
    let tickets: [Ticket]
    let accent: Color
    let compact: Bool
    let onSelect: () -> Void
    let onDrop: (UUID) -> Void

    @State private var isTargeted = false

    private var overdue: Bool {
        !isToday && day < Calendar.current.startOfDay(for: Date()) && tickets.contains { $0.status != .done }
    }

    var body: some View {
        VStack(alignment: compact ? .center : .leading, spacing: 3) {
            Text(day.formatted(.dateTime.day()))
                .font(compact ? .callout : .caption)
                .fontWeight(isToday || isSelected ? .bold : .regular)
                .monospacedDigit()
                .foregroundStyle(isToday ? .white : (overdue ? .red : (inMonth ? .primary : .secondary)))
                .opacity(inMonth || isToday ? 1 : 0.5)
                .frame(width: compact ? 30 : 22, height: compact ? 30 : 22)
                .background(RoundedRectangle(cornerRadius: Radius.small).fill(isToday ? accent : .clear))

            if compact {
                HStack(spacing: 3) {
                    ForEach(tickets.prefix(3)) { ticket in
                        Circle()
                            .fill(ticket.category.color.opacity(ticket.status == .done ? 0.35 : 1))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            } else {
                ForEach(tickets.prefix(3)) { ticket in
                    chip(ticket)
                }
                if tickets.count > 3 {
                    Text("+\(tickets.count - 3) more")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(compact ? 3 : 5)
        .frame(maxWidth: .infinity, minHeight: compact ? 46 : 64, maxHeight: compact ? nil : .infinity,
               alignment: compact ? .top : .topLeading)
        .background {
            RoundedRectangle(cornerRadius: compact ? Radius.small : 0)
                .fill(isSelected ? accent.opacity(0.16) : (isTargeted ? accent.opacity(0.10) : .clear))
        }
        .overlay {
            if !compact { Rectangle().stroke(Color.primary.opacity(0.07), lineWidth: 0.5) }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .dropDestination(for: String.self) { items, _ in
            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
            onDrop(id)
            return true
        } isTargeted: { isTargeted = $0 }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)), \(tickets.count) ticket\(tickets.count == 1 ? "" : "s")")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func chip(_ ticket: Ticket) -> some View {
        let done = ticket.status == .done
        return HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 1).fill(ticket.category.color).frame(width: 3)
            Text(ticket.title)
                .font(.system(size: 11))
                .lineLimit(1)
                .strikethrough(done)
                .foregroundStyle(done ? .secondary : .primary)
        }
        .padding(.vertical, 2)
        .padding(.trailing, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.tiny).fill(ticket.category.color.opacity(done ? 0.06 : 0.14)))
        .draggable(ticket.id.uuidString)
    }
}

private extension View {
    func scrollableIfNeeded() -> some View {
        ScrollView { self }
    }
}
