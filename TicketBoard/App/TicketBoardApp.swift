import KeyboardShortcuts
import SwiftData
import SwiftUI

extension KeyboardShortcuts.Name {
    static let quickAdd = Self("quickAdd", default: .init(.space, modifiers: [.option]))
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        MainActor.assumeIsolated {
            AppModel.shared.startWatchingWidgetWrites()
            KeyboardShortcuts.onKeyUp(for: .quickAdd) {
                AppModel.shared.quickAdd.toggle()
            }
        }
    }

    // The menu bar extra keeps the app useful with no windows open.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct TicketBoardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var model = AppModel.shared

    var body: some Scene {
        Window("Ticket Board", id: WindowID.board) {
            BoardView()
                .id(model.generation)
                .environment(model)
                .modelContainer(model.container)
                .onOpenURL { model.handle($0) }
                .frame(minWidth: 900, minHeight: 520)
        }
        .defaultSize(width: 1180, height: 720)
        .commands { TicketCommands(model: model) }

        Window("Stats", id: WindowID.stats) {
            StatsView()
                .id(model.generation)
                .modelContainer(model.container)
                .frame(minWidth: 620, minHeight: 520)
        }
        .defaultSize(width: 760, height: 680)

        MenuBarExtra {
            MenuBarContent()
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

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Ticket") {
                openWindow(id: WindowID.board)
                model.newTicketRequest = .backlog
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

        CommandMenu("Rewards") {
            Button("Redeem Want…") { model.redeemKind = .want }
                .keyboardShortcut("w", modifiers: [.command, .shift])
            Button("Redeem Fun…") { model.redeemKind = .fun }
                .keyboardShortcut("f", modifiers: [.command, .shift])
            Divider()
            Button("Stats") { openWindow(id: WindowID.stats) }
                .keyboardShortcut("s", modifiers: [.command, .shift])
        }
    }
}
