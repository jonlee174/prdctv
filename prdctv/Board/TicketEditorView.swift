import SwiftData
import SwiftUI

/// Create or edit a ticket. Status is changed on the board, not here,
/// so reward unlocks always go through the confirm step.
struct TicketEditorView: View {
    let target: EditTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""
    @State private var category = Category.need
    @State private var points = 1
    @State private var hasDue = false
    @State private var dueDate = Calendar.current.startOfDay(for: Date())
    @State private var tags: [String] = []
    @State private var tagText = ""
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true
    @Query private var allTickets: [Ticket]
    @FocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Form {
                TextField("Title", text: $title)
                    .focused($titleFocused)
                    .font(.title3)

                if rewardsEnabled {
                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases) { cat in
                            Label(cat.label, systemImage: cat.symbol).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if pointsEnabled {
                    Picker("Points", selection: $points) {
                        ForEach(PointScale.values, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Toggle("Due date", isOn: $hasDue)
                if hasDue {
                    DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                }

                TagField(tags: $tags, text: $tagText, known: knownTags)

                TextField("Notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .formStyle(.grouped)

            HStack {
                if case .existing(let ticket) = target {
                    Button("Delete", role: .destructive) {
                        TicketOps.delete(ticket, context: context)
                        dismiss()
                    }
                }
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button(isNew ? "Add Ticket" : "Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .macFrame(width: 440)
        .onAppear(perform: load)
    }

    private var knownTags: [String] {
        TicketTags.allTags(in: allTickets.map(\.tags))
    }

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    private func load() {
        if case .new(_, let due?) = target {
            hasDue = true
            dueDate = Calendar.current.startOfDay(for: due)
        }
        if case .existing(let ticket) = target {
            title = ticket.title
            notes = ticket.notes
            category = ticket.category
            points = ticket.points
            hasDue = ticket.dueDate != nil
            dueDate = ticket.dueDate ?? dueDate
            tags = ticket.tags
        }
        titleFocused = true
    }

    private func save() {
        let tags = TicketTags.canonical(self.tags + tagText.split(separator: ",").map(String.init), known: knownTags)
        let cleanTitle = title.trimmingCharacters(in: .whitespaces)
        let due = hasDue ? dueDate : nil

        switch target {
        case .new(let status, _):
            // Reward tickets can't be created already started; they begin in Up Next at most.
            let start: Status = category.isReward && status.requiresUnlock ? .upNext : status
            TicketOps.add(title: cleanTitle, category: category, points: points, status: start,
                          dueDate: due, tags: tags, notes: notes, context: context)
        case .existing(let ticket):
            ticket.title = cleanTitle
            ticket.notes = notes
            ticket.category = category
            ticket.points = points
            ticket.dueDate = due
            ticket.tags = tags
            TicketOps.save(context)
        }
        dismiss()
    }
}

/// Current tags as removable chips, a field to add more, and matching tags already in use.
private struct TagField: View {
    @Binding var tags: [String]
    @Binding var text: String
    let known: [String]

    private var suggestions: [String] {
        let query = TicketTags.normalize(text).lowercased()
        let applied = Set(tags.map { $0.lowercased() })
        return known
            .filter { !applied.contains($0.lowercased()) && (query.isEmpty || $0.lowercased().contains(query)) }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("Tags", text: $text, prompt: Text("class or topic, return to add"))
                .onSubmit { add(text) }
                .onChange(of: text) { _, new in
                    // A comma finishes the tag typed before it.
                    if new.contains(",") { add(new) }
                }
            if !tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(tags, id: \.self) { tag in
                        Button { tags.removeAll { $0 == tag } } label: {
                            HStack(spacing: 2) {
                                TagChip(tag: tag, size: 11)
                                Image(systemName: "xmark.circle.fill").font(.system(size: 10)).foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .help("Remove \(tag)")
                    }
                }
            }
            if !suggestions.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(suggestions, id: \.self) { tag in
                        Button { add(tag) } label: {
                            TagChip(tag: tag, size: 11).opacity(0.6)
                        }
                        .buttonStyle(.plain)
                        .help("Add \(tag)")
                    }
                }
            }
        }
    }

    private func add(_ raw: String) {
        tags = TicketTags.canonical(tags + raw.split(separator: ",").map(String.init), known: known)
        text = ""
    }
}

/// Completed tickets older than the current week, grouped by week.
struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @Query(filter: #Predicate<Ticket> { $0.statusRaw == "done" }, sort: \Ticket.completedAt, order: .reverse)
    private var done: [Ticket]
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true

    private var weeks: [(start: Date, tickets: [Ticket])] {
        let cal = Calendar.current
        let older = done.filter {
            guard let date = $0.completedAt else { return true }
            return !cal.isDate(date, equalTo: Date(), toGranularity: .weekOfYear)
        }
        let groups = Dictionary(grouping: older) {
            cal.dateInterval(of: .weekOfYear, for: $0.completedAt ?? .distantPast)?.start ?? .distantPast
        }
        return groups.keys.sorted(by: >).map { ($0, groups[$0]!) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("History").font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding()

            if weeks.isEmpty {
                ContentUnavailableView("No older tickets", systemImage: "clock",
                                       description: Text("Tickets completed before this week show up here."))
            } else {
                List {
                    ForEach(weeks, id: \.start) { week in
                        Section {
                            ForEach(week.tickets) { ticket in
                                HStack {
                                    Image(systemName: ticket.category.symbol)
                                        .foregroundStyle(ticket.category.color)
                                        .font(.caption)
                                    Text(ticket.title)
                                    Spacer()
                                    if pointsEnabled {
                                        Text("\(ticket.points) pts").foregroundStyle(.secondary).monospacedDigit()
                                    }
                                    Button("Reopen") {
                                        TicketOps.move(ticket, to: .upNext, context: context)
                                    }
                                    .buttonStyle(.borderless)
                                    .help("Move back to Up Next (it no longer counts toward rewards)")
                                }
                            }
                        } header: {
                            let settings = RewardSettings.load()
                            let needValue = week.tickets.filter { $0.category == .need }.reduce(0) { $0 + settings.value(ofPoints: $1.points) }
                            Text("Week of \(week.start.formatted(date: .abbreviated, time: .omitted)) · \(needValue) \(settings.needUnit(needValue))")
                        }
                    }
                }
            }
        }
        .macFrame(width: 520, height: 520)
    }
}
