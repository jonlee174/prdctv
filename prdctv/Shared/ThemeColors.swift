import SwiftUI

/// Colors for the board columns, the calendar and the app accent. Each defaults to a green
/// from the logo's palette and can be changed; resetting returns to that default.
/// Stored as "#RRGGBB" in the App Group defaults so the widget can use them too
/// (no value or "" = the default).
///
/// Key names must not contain dots: SwiftUI observes these settings through key-value
/// observing, which treats a dot as a key path separator, so other views would never
/// hear about changes.
enum ThemeColorKey: String, CaseIterable, Identifiable {
    case upNext, inProgress, done, calendar, accent

    var id: String { rawValue }
    var defaultsKey: String { "color" + rawValue.prefix(1).uppercased() + rawValue.dropFirst() }

    init(_ status: Status) {
        switch status {
        case .upNext: self = .upNext
        case .inProgress: self = .inProgress
        case .done: self = .done
        }
    }

    var label: String {
        switch self {
        case .upNext: Status.upNext.label
        case .inProgress: Status.inProgress.label
        case .done: Status.done.label
        case .calendar: "Calendar"
        case .accent: "Accent"
        }
    }

    /// Default green, derived from the logo's hue (#8ED973) and kept dark enough to read as
    /// text on light and dark backgrounds.
    var suggestedHex: String {
        switch self {
        case .upNext: "#55A838"
        case .inProgress: "#3E8A38"
        case .done: "#4B8154"
        case .calendar: "#4D9B31"
        case .accent: "#408A2E"
        }
    }
}

/// Reads the theme colors: the user's choice, or the default green.
struct ThemeColors: DynamicProperty {
    @AppStorage(ThemeColorKey.upNext.defaultsKey, store: AppGroup.defaults) private var upNext = ""
    @AppStorage(ThemeColorKey.inProgress.defaultsKey, store: AppGroup.defaults) private var inProgress = ""
    @AppStorage(ThemeColorKey.done.defaultsKey, store: AppGroup.defaults) private var done = ""
    @AppStorage(ThemeColorKey.calendar.defaultsKey, store: AppGroup.defaults) private var calendarHex = ""
    @AppStorage(ThemeColorKey.accent.defaultsKey, store: AppGroup.defaults) private var accentHex = ""

    func column(_ status: Status) -> Color {
        switch status {
        case .upNext: resolved(upNext, .upNext)
        case .inProgress: resolved(inProgress, .inProgress)
        case .done: resolved(done, .done)
        }
    }

    var calendar: Color { resolved(calendarHex, .calendar) }

    /// Tint for buttons, switches, selection and links.
    var accent: Color { resolved(accentHex, .accent) }

    private func resolved(_ hex: String, _ key: ThemeColorKey) -> Color {
        Color(hex: hex) ?? Color(hex: key.suggestedHex)!
    }
}

private struct BrandTint: ViewModifier {
    private var theme = ThemeColors()

    func body(content: Content) -> some View {
        content.tint(theme.accent)
    }
}

extension View {
    /// Applies the accent color from Settings → Colors (green by default).
    func brandTint() -> some View {
        modifier(BrandTint())
    }
}

extension Color {
    /// Parses "#RRGGBB"; returns nil for an empty or malformed string.
    init?(hex: String) {
        let digits = hex.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        let c = resolve(in: EnvironmentValues())
        func byte(_ v: Float) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(c.red), byte(c.green), byte(c.blue))
    }
}

/// Settings rows for the column, calendar and accent colors. Picking a color in the swatch
/// (system color picker / color wheel) applies it immediately; ↺ undoes the last change.
/// "Reset to Default" is in the row's context menu.
struct ThemeColorSettings: View {
    var body: some View {
        ForEach(ThemeColorKey.allCases) { key in
            ThemeColorRow(key: key)
        }
    }
}

private struct ThemeColorRow: View {
    let key: ThemeColorKey
    /// Chosen color; empty means the default.
    @AppStorage private var hex: String
    @AppStorage private var historyRaw: String
    @State private var lastChange: Date?

    init(key: ThemeColorKey) {
        self.key = key
        _hex = AppStorage(wrappedValue: "", key.defaultsKey, store: AppGroup.defaults)
        _historyRaw = AppStorage(wrappedValue: "", key.defaultsKey + "History", store: AppGroup.defaults)
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(key.label)
            Spacer()
            if UndoHistory(raw: historyRaw).canUndo {
                UndoButton(label: key.label, action: undo)
            }
            HexColorPicker(title: "\(key.label) color", hex: hex.isEmpty ? key.suggestedHex : hex) {
                change(to: $0)
            }
            .help("Choose the \(key.label) color")
        }
        .contextMenu {
            Button("Reset to Default") { change(to: "", continuing: false) }
                .disabled(hex.isEmpty)
        }
        .onChange(of: hex) { SharedStore.reloadWidgets() }
    }

    private func change(to new: String, continuing: Bool = true) {
        guard new != hex, !(hex.isEmpty && new == key.suggestedHex) else { return }
        var history = UndoHistory(raw: historyRaw)
        history.record(hex, at: Date(), lastChange: continuing ? lastChange : nil)
        historyRaw = history.raw
        lastChange = continuing ? Date() : nil
        hex = new
    }

    private func undo() {
        var history = UndoHistory(raw: historyRaw)
        guard let previous = history.pop() else { return }
        historyRaw = history.raw
        lastChange = nil
        hex = previous
    }
}

/// A ColorPicker that saves "#RRGGBB" but keeps its own color while in use.
/// Feeding the rounded hex back mid-drag moves the panel's sliders under the mouse.
struct HexColorPicker: View {
    let title: String
    /// The current color, including the default when nothing is chosen.
    let hex: String
    let onChange: (String) -> Void

    @State private var color: Color
    @State private var lastHex: String

    init(title: String, hex: String, onChange: @escaping (String) -> Void) {
        self.title = title
        self.hex = hex
        self.onChange = onChange
        _color = State(initialValue: Color(hex: hex) ?? .gray)
        _lastHex = State(initialValue: hex)
    }

    var body: some View {
        ColorPicker(title, selection: $color, supportsOpacity: false)
            .labelsHidden()
            .onChange(of: color) { _, new in
                let newHex = new.hexString
                guard newHex != lastHex else { return }
                lastHex = newHex
                onChange(newHex)
            }
            .onChange(of: hex) { _, new in
                // Only outside changes like reset or undo move the picker.
                guard new.caseInsensitiveCompare(lastHex) != .orderedSame else { return }
                lastHex = new
                color = Color(hex: new) ?? color
            }
    }
}

/// The ↺ shown when a setting has changes to undo.
private struct UndoButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.uturn.backward")
        }
        .buttonStyle(.borderless)
        .help("Undo the last \(label) change")
        .accessibilityLabel("Undo \(label) change")
    }
}

// MARK: - Category style (Need / Want / Fun)

/// Settings rows for each category: icon (grid of symbols), color (system color picker), and reset.
struct CategoryStyleSettings: View {
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true

    var body: some View {
        ForEach(Category.shown(rewardsEnabled: rewardsEnabled)) { category in
            CategoryStyleRow(category: category)
        }
    }
}

private struct CategoryStyleRow: View {
    let category: Category
    @AppStorage private var hex: String
    @AppStorage private var symbol: String
    /// Undo entries are "color|icon" snapshots, so one ↺ covers whichever changed last.
    @AppStorage private var historyRaw: String
    @State private var lastColorChange: Date?
    @State private var showIcons = false

    init(category: Category) {
        self.category = category
        _hex = AppStorage(wrappedValue: "", category.colorKey, store: AppGroup.defaults)
        _symbol = AppStorage(wrappedValue: "", category.symbolKey, store: AppGroup.defaults)
        _historyRaw = AppStorage(wrappedValue: "", "category\(category.label)History", store: AppGroup.defaults)
    }

    private var color: Color { Color(hex: hex) ?? Color(hex: category.defaultColorHex)! }
    private var icon: String { Category.symbolChoices.contains(symbol) ? symbol : category.defaultSymbol }
    private var snapshot: String { "\(hex)|\(symbol)" }

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(category.label)
            } icon: {
                Image(systemName: icon).foregroundStyle(color)
            }
            Spacer()
            if UndoHistory(raw: historyRaw).canUndo {
                UndoButton(label: category.label, action: undo)
            }
            Button {
                showIcons = true
            } label: {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .frame(width: 22, height: 18)
            }
            .buttonStyle(.bordered)
            .help("Choose the \(category.label) icon")
            .popover(isPresented: $showIcons) {
                SymbolGrid(selection: icon, color: color) { chosen in
                    let new = chosen == category.defaultSymbol ? "" : chosen
                    if new != symbol { apply(color: hex, symbol: new, continuing: false) }
                    showIcons = false
                }
                #if os(iOS)
                .presentationCompactAdaptation(.popover)
                #endif
            }
            HexColorPicker(title: "\(category.label) color", hex: hex.isEmpty ? category.defaultColorHex : hex) { new in
                guard new != hex, !(hex.isEmpty && new == category.defaultColorHex) else { return }
                apply(color: new, symbol: symbol, continuing: true)
            }
            .help("Choose the \(category.label) color")
        }
        .contextMenu {
            Button("Reset to Default") { apply(color: "", symbol: "", continuing: false) }
                .disabled(hex.isEmpty && symbol.isEmpty)
        }
        .onChange(of: hex) { SharedStore.reloadWidgets() }
        .onChange(of: symbol) { SharedStore.reloadWidgets() }
    }

    /// `continuing`: part of a color-wheel drag, so it merges into the edit already recorded.
    private func apply(color newColor: String, symbol newSymbol: String, continuing: Bool) {
        var history = UndoHistory(raw: historyRaw)
        history.record(snapshot, at: Date(), lastChange: continuing ? lastColorChange : nil)
        historyRaw = history.raw
        lastColorChange = continuing ? Date() : nil
        hex = newColor
        symbol = newSymbol
    }

    private func undo() {
        var history = UndoHistory(raw: historyRaw)
        guard let previous = history.pop() else { return }
        historyRaw = history.raw
        lastColorChange = nil
        let parts = previous.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
        hex = parts.first ?? ""
        symbol = parts.count > 1 ? parts[1] : ""
    }
}

private struct SymbolGrid: View {
    let selection: String
    let color: Color
    let onPick: (String) -> Void

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(38), spacing: 6), count: 6), spacing: 6) {
            ForEach(Category.symbolChoices, id: \.self) { name in
                Button {
                    onPick(name)
                } label: {
                    Image(systemName: name)
                        .font(.title3)
                        .foregroundStyle(name == selection ? color : .primary)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.small)
                                .fill(name == selection ? color.opacity(0.2) : Color.primary.opacity(0.05))
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(name.replacingOccurrences(of: ".fill", with: "").replacingOccurrences(of: ".", with: " "))
            }
        }
        .padding(12)
    }
}

/// Category colors and icons are read directly from settings wherever they're drawn,
/// so screens need a nudge to redraw when they change. This rebuilds the wrapped view
/// whenever any category style setting changes.
private struct CategoryStyleRefresh: ViewModifier {
    @AppStorage(Category.need.colorKey, store: AppGroup.defaults) private var needColor = ""
    @AppStorage(Category.want.colorKey, store: AppGroup.defaults) private var wantColor = ""
    @AppStorage(Category.fun.colorKey, store: AppGroup.defaults) private var funColor = ""
    @AppStorage(Category.need.symbolKey, store: AppGroup.defaults) private var needSymbol = ""
    @AppStorage(Category.want.symbolKey, store: AppGroup.defaults) private var wantSymbol = ""
    @AppStorage(Category.fun.symbolKey, store: AppGroup.defaults) private var funSymbol = ""

    func body(content: Content) -> some View {
        content.id([needColor, wantColor, funColor, needSymbol, wantSymbol, funSymbol].joined(separator: "|"))
    }
}

extension View {
    func refreshesOnCategoryStyle() -> some View {
        modifier(CategoryStyleRefresh())
    }
}
