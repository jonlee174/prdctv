import SwiftUI

extension TicketTags {
    /// System hues away from the green category palette, and no red since red marks overdue.
    static let palette: [Color] = [.blue, .purple, .orange, .pink, .teal, .indigo, .brown, .cyan]

    static func defaultColor(for tag: String) -> Color {
        palette[colorIndex(for: tag, count: palette.count)]
    }

    /// The color chosen in Settings, or the default from the tag's name.
    static func color(for tag: String, colorsRaw: String? = nil) -> Color {
        let raw = colorsRaw ?? AppGroup.defaults.string(forKey: colorsKey) ?? ""
        return decodeColors(raw)[tag.lowercased()].flatMap { Color(hex: $0) } ?? defaultColor(for: tag)
    }
}

/// The color a task is drawn in. Its first tag's color, standard green without a tag, or its category color.
struct TaskColoring: DynamicProperty {
    @AppStorage(TicketTags.colorTasksByTagKey, store: AppGroup.defaults) private var byTag = true
    @AppStorage(TicketTags.colorsKey, store: AppGroup.defaults) private var colorsRaw = ""

    /// Standard green, the default Need color, for tasks without a tag.
    static let untagged = Color(hex: Category.need.defaultColorHex)!

    func color(category: Category, tags: [String]) -> Color {
        guard byTag else { return category.color }
        return tags.first.map { TicketTags.color(for: $0, colorsRaw: colorsRaw) } ?? Self.untagged
    }
}

/// A tag drawn as a small tinted label so a class keeps one color everywhere.
struct TagChip: View {
    let tag: String
    var size: CGFloat = 10
    // Observed so chips redraw when a tag color changes in Settings.
    @AppStorage(TicketTags.colorsKey, store: AppGroup.defaults) private var colorsRaw = ""

    init(tag: String, size: CGFloat = 10) {
        self.tag = tag
        self.size = size
    }

    var body: some View {
        let color = TicketTags.color(for: tag, colorsRaw: colorsRaw)
        Text(tag)
            .font(.system(size: size, weight: .semibold))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, size * 0.45)
            .padding(.vertical, size * 0.1)
            .background(RoundedRectangle(cornerRadius: Radius.tiny).fill(color.opacity(0.15)))
            .accessibilityLabel("tag \(tag)")
    }
}

/// Wraps children onto new lines when a row runs out of width.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - size.height) / 2), proposal: .unspecified)
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width += (row.indices.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
