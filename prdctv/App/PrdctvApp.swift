import KeyboardShortcuts
import SwiftData
import SwiftUI

extension KeyboardShortcuts.Name {
    static let quickAdd = Self("quickAdd", default: .init(.space, modifiers: [.option]))
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppAppearance.current.apply()
            AppModel.shared.startWatchingWidgetWrites()
            KeyboardShortcuts.onKeyUp(for: .quickAdd) {
                AppModel.shared.quickAdd.toggle()
            }
            #if DEBUG
            ScreenshotSetup.apply()
            #endif
        }
    }

    // The menu bar extra keeps the app useful with no windows open.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

#if DEBUG
/// Debug launch options for App Store screenshots, e.g. `--mode=calendar --lanes=tag --appearance=light`.
/// Values are joined with "=" because a separate word launches the app as if opening a file, with no window.
@MainActor
enum ScreenshotSetup {
    private static func value(_ name: String) -> String? {
        ProcessInfo.processInfo.arguments.first { $0.hasPrefix("--\(name)=") }.map { String($0.dropFirst(name.count + 3)) }
    }

    /// Lanes and appearance for this launch only, set before any view reads them.
    static func applyDefaults() {
        var overrides: [String: Any] = [:]
        if let lanes = value("lanes") { overrides[LaneGrouping.storageKey] = lanes }
        if let appearance = value("appearance") { overrides[AppAppearance.storageKey] = appearance }
        guard !overrides.isEmpty else { return }
        UserDefaults.standard.setVolatileDomain(overrides, forName: UserDefaults.argumentDomain)
    }

    static func apply() {
        if let mode = value("mode").flatMap(BoardMode.init) { AppModel.shared.boardMode = mode }
        guard let size = value("window-size")?.split(separator: "x").compactMap({ Double($0) }), size.count == 2 else { return }
        // The board window appears a moment after launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            guard let window = NSApp.windows.filter({ $0.isVisible && $0.canBecomeMain }).max(by: { $0.frame.width < $1.frame.width }),
                  let screen = window.screen?.visibleFrame else { return }
            window.setFrame(NSRect(x: screen.minX + 20, y: screen.maxY - size[1] - 10, width: size[0], height: size[1]), display: true)
        }
    }
}
#endif

@main
struct PrdctvApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared

    init() {
        #if DEBUG
        ScreenshotSetup.applyDefaults()
        #endif
    }

    var body: some Scene {
        Window("prdctv", id: WindowID.board) {
            BoardView()
                .refreshesOnCategoryStyle()
                .brandTint()
                .id(model.generation)
                .environment(model)
                .modelContainer(model.container)
                .onOpenURL { model.handle($0) }
                .frame(minWidth: 900, minHeight: 520)
        }
        .defaultSize(width: 1180, height: 720)
        .windowToolbarStyle(.unified(showsTitle: false))
        .commands { TicketCommands(model: model) }

        Window("Stats", id: WindowID.stats) {
            StatsView()
                .refreshesOnCategoryStyle()
                .brandTint()
                .id(model.generation)
                .modelContainer(model.container)
                .frame(minWidth: 620, minHeight: 520)
        }
        .defaultSize(width: 760, height: 680)

        MenuBarExtra {
            MenuBarContent()
                .refreshesOnCategoryStyle()
                .brandTint()
                .id(model.generation)
                .environment(model)
                .modelContainer(model.container)
        } label: {
            MenuBarLabel()
                .id(model.generation)
                .modelContainer(model.container)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .brandTint()
                .id(model.generation)
                .modelContainer(model.container)
        }
    }
}

enum WindowID {
    static let board = "board"
    static let stats = "stats"
}

struct TicketCommands: Commands {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Ticket") {
                openWindow(id: WindowID.board)
                model.newTicketRequest = .upNext
            }
            .keyboardShortcut("n")

            Button("Quick Add…") { model.quickAdd.show() }
                .keyboardShortcut("k")

            Divider()

            Button("Import Whiteboard Photo…") {
                openWindow(id: WindowID.board)
                model.showImport = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])
        }

        CommandGroup(before: .toolbar) {
            Button("Board") { model.boardMode = .board }
                .keyboardShortcut("1")
            Button("Calendar") { model.boardMode = .calendar }
                .keyboardShortcut("2")
            Button("Stats") { openWindow(id: WindowID.stats) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            Divider()
        }

        if rewardsEnabled {
            CommandMenu("Rewards") {
                Button("Redeem Want…") { model.redeemKind = .want }
                    .keyboardShortcut("w", modifiers: [.command, .shift])
                Button("Redeem Fun…") { model.redeemKind = .fun }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
            }
        }
    }
}
