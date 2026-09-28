import SwiftData
import SwiftUI

/// Settings rows with a color swatch for every tag in use.
struct TagColorSettings: View {
    @Query private var tickets: [Ticket]
    @AppStorage(TicketTags.colorsKey, store: AppGroup.defaults) private var colorsRaw = ""

    private var tags: [String] {
        TicketTags.sortedTags(in: tickets.map(\.tags))
    }

    var body: some View {
        if tags.isEmpty {
            Text("No tags yet").foregroundStyle(.secondary)
        }
        ForEach(tags, id: \.self) { tag in
            let chosen = TicketTags.decodeColors(colorsRaw)[tag.lowercased()]
            HStack(spacing: 12) {
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
    }

    private func setColor(_ hex: String?, for tag: String) {
        var colors = TicketTags.decodeColors(colorsRaw)
        colors[tag.lowercased()] = hex
        colorsRaw = TicketTags.encodeColors(colors)
    }
}

/// Widget layout switches, stored where the widget can read them.
struct WidgetSettings: View {
    @AppStorage(TicketTags.widgetListByTagKey, store: AppGroup.defaults) private var listByTag = false
    @AppStorage(TicketTags.widgetShowsMiscellaneousKey, store: AppGroup.defaults) private var showsMiscellaneous = true
    @AppStorage(RewardSettings.largeWidgetShowsMeterKey, store: AppGroup.defaults) private var largeShowsMeter = true
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true

    var body: some View {
        Toggle("List by tag", isOn: $listByTag)
            .onChange(of: listByTag) { SharedStore.reloadWidgets() }
        Toggle("Show miscellaneous", isOn: $showsMiscellaneous)
            .disabled(!listByTag)
            .help("Untagged tickets, listed last")
            .onChange(of: showsMiscellaneous) { SharedStore.reloadWidgets() }
        Toggle("Rewards in the large widget", isOn: $largeShowsMeter)
            .disabled(!rewardsEnabled)
            .onChange(of: largeShowsMeter) { SharedStore.reloadWidgets() }
    }
}
