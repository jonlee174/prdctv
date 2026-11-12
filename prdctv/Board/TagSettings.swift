import SwiftData
import SwiftUI

/// Settings rows for tag colors and tag order, with every tag in use listed in priority order.
struct TagColorSettings: View {
    @Query private var tickets: [Ticket]
    @AppStorage(TicketTags.colorsKey, store: AppGroup.defaults) private var colorsRaw = ""
    @AppStorage(TicketTags.colorTasksByTagKey, store: AppGroup.defaults) private var colorTasksByTag = true
    @AppStorage(TicketTags.tagOrderKey, store: AppGroup.defaults) private var tagOrderRaw = TagLaneOrder.Tags.custom.rawValue
    @AppStorage(TicketTags.tagTaskOrderKey, store: AppGroup.defaults) private var taskOrderRaw = TagLaneOrder.Tasks.board.rawValue
    @AppStorage(TicketTags.tagPriorityKey, store: AppGroup.defaults) private var priorityRaw = ""

    private var tags: [String] {
        TagLaneOrder(tagsRaw: tagOrderRaw, tasksRaw: taskOrderRaw, priorityRaw: priorityRaw)
            .byPriority(TicketTags.sortedTags(in: tickets.map(\.tags)))
    }

    var body: some View {
        Toggle("Color tasks by tag", isOn: $colorTasksByTag)
            .help("Tasks use their first tag's color, or green without a tag")
            .onChange(of: colorTasksByTag) { SharedStore.reloadWidgets() }
        Picker("Tag order", selection: $tagOrderRaw) {
            Text("Custom").tag(TagLaneOrder.Tags.custom.rawValue)
            Text("Soonest due date").tag(TagLaneOrder.Tags.dueDate.rawValue)
        }
        .help("How tag lanes and List by tag in the widget are ordered")
        .onChange(of: tagOrderRaw) { SharedStore.reloadWidgets() }
        Picker("Tasks in a tag", selection: $taskOrderRaw) {
            Text("Board order").tag(TagLaneOrder.Tasks.board.rawValue)
            Text("Soonest due date").tag(TagLaneOrder.Tasks.dueDate.rawValue)
        }
        .onChange(of: taskOrderRaw) { SharedStore.reloadWidgets() }
        if tags.isEmpty {
            Text("No tags yet").foregroundStyle(.secondary)
        }
        ForEach(Array(tags.enumerated()), id: \.element) { index, tag in
            let chosen = TicketTags.decodeColors(colorsRaw)[tag.lowercased()]
            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Button { move(tag, by: -1) } label: { Image(systemName: "chevron.up") }
                        .disabled(index == 0)
                        .accessibilityLabel("Move \(tag) up")
                    Button { move(tag, by: 1) } label: { Image(systemName: "chevron.down") }
                        .disabled(index == tags.count - 1)
                        .accessibilityLabel("Move \(tag) down")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 10, weight: .semibold))
                .help("Change \(tag)'s priority")
                TagChip(tag: tag, size: 12)
                Spacer()
                if chosen != nil {
                    Button { setColor(nil, for: tag) } label: { Image(systemName: "arrow.uturn.backward") }
                        .buttonStyle(.borderless)
                        .help("Use the default color for \(tag)")
                        .accessibilityLabel("Reset \(tag) color")
                }
                HexColorPicker(title: "\(tag) color", hex: TicketTags.color(for: tag, colorsRaw: colorsRaw).hexString) {
                    setColor($0, for: tag)
                }
                .help("Choose the \(tag) color")
            }
            .contextMenu {
                Button("Reset to Default") { setColor(nil, for: tag) }
                    .disabled(chosen == nil)
            }
        }
        .onChange(of: colorsRaw) { SharedStore.reloadWidgets() }
        .onChange(of: priorityRaw) { SharedStore.reloadWidgets() }
    }

    /// Swaps a tag with its neighbor and saves the whole list as the priority order.
    private func move(_ tag: String, by offset: Int) {
        var list = tags.map { $0.lowercased() }
        guard let index = list.firstIndex(of: tag.lowercased()), list.indices.contains(index + offset) else { return }
        list.swapAt(index, index + offset)
        priorityRaw = TagLaneOrder.encodePriority(list)
    }

    private func setColor(_ hex: String?, for tag: String) {
        var colors = TicketTags.decodeColors(colorsRaw)
        colors[tag.lowercased()] = hex
        colorsRaw = TicketTags.encodeColors(colors)
    }
}

/// Widget layout switches, stored where the widget can read them.
struct WidgetSettings: View {
    // Falls back to the older List by tag switch until a layout is picked here.
    @AppStorage(TicketTags.widgetLayoutKey, store: AppGroup.defaults) private var layoutRaw = WidgetLayout.load().rawValue
    @AppStorage(TicketTags.widgetStatusTitlesKey, store: AppGroup.defaults) private var statusTitles = true
    @AppStorage(TicketTags.widgetStatusShowsTagsKey, store: AppGroup.defaults) private var statusShowsTags = true
    @AppStorage(TicketTags.widgetShowsMiscellaneousKey, store: AppGroup.defaults) private var showsMiscellaneous = true
    @AppStorage(RewardSettings.largeWidgetShowsMeterKey, store: AppGroup.defaults) private var largeShowsMeter = true
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    @AppStorage(TicketTags.widgetShowsDueDatesKey, store: AppGroup.defaults) private var showsDueDates = false

    var body: some View {
        Toggle("Due dates", isOn: $showsDueDates)
            .help("The weekday within a week, otherwise the date")
            .onChange(of: showsDueDates) { SharedStore.reloadWidgets() }
        Picker("Layout", selection: $layoutRaw) {
            Text("Columns").tag(WidgetLayout.columns.rawValue)
            Text("By tag").tag(WidgetLayout.tags.rawValue)
            Text("By status").tag(WidgetLayout.status.rawValue)
        }
        .onChange(of: layoutRaw) { SharedStore.reloadWidgets() }
        // Only the switches that apply to the chosen layout and features are shown.
        if layoutRaw == WidgetLayout.tags.rawValue {
            Toggle("Show miscellaneous", isOn: $showsMiscellaneous)
                .help("Untagged tickets, listed last")
                .onChange(of: showsMiscellaneous) { SharedStore.reloadWidgets() }
        }
        if layoutRaw == WidgetLayout.status.rawValue {
            Toggle("Status titles", isOn: $statusTitles)
                .help("In Progress and Up Next titles")
                .onChange(of: statusTitles) { SharedStore.reloadWidgets() }
            Toggle("Tags in rows", isOn: $statusShowsTags)
                .help("Each row's first tag")
                .onChange(of: statusShowsTags) { SharedStore.reloadWidgets() }
        }
        if rewardsEnabled {
            Toggle("Rewards in the large widget", isOn: $largeShowsMeter)
                .onChange(of: largeShowsMeter) { SharedStore.reloadWidgets() }
        }
    }
}
