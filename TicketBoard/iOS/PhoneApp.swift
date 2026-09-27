import SwiftData
import SwiftUI

/// iPhone/iPad app state: owns the store and routes deep links from the widget.
@MainActor
@Observable
final class PhoneModel {
    /// `--demo`: in-memory store with sample tickets.
    let store = StoreController(demo: ProcessInfo.processInfo.arguments.contains("--demo"))

    var tab = PhoneTab.initial
    /// Deep link target: the board opens this ticket's editor.
    var openTicketID: UUID?
    var redeemKind: Category?
    var showRedeemPicker = false
    var showQuickAdd = false

    func handle(_ url: URL) {
        store.refreshIfNeeded()
        switch DeepLink(url: url) {
        case .ticket(let id):
            tab = .board
            openTicketID = id
        case .redeem:
            tab = .board
            showRedeemPicker = true
        case .quickAdd:
            tab = .board
            showQuickAdd = true
        case nil:
            break
        }
    }
}

enum PhoneTab: String, Hashable {
    case board, calendar, stats, settings

    /// Debug builds accept `--tab calendar` (etc.) to open on a tab, e.g. for screenshots.
    static var initial: PhoneTab {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--tab"), args.indices.contains(i + 1),
           let tab = PhoneTab(rawValue: args[i + 1]) {
            return tab
        }
        #endif
        return .board
    }
}

@main
struct TicketBoardPhoneApp: App {
    @State private var model = PhoneModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .brandTint()
                .id(model.store.generation)
                .environment(model)
                .modelContainer(model.store.container)
                .onOpenURL { model.handle($0) }
                .onChange(of: scenePhase) { _, phase in
                    // Pick up completions made from the widget while we were in the background.
                    if phase == .active { model.store.refreshIfNeeded() }
                }
        }
    }
}

struct PhoneRootView: View {
    @Environment(PhoneModel.self) private var model

    var body: some View {
        @Bindable var model = model

        TabView(selection: $model.tab) {
            PhoneBoardView()
                .refreshesOnCategoryStyle()
                .tabItem { Label("Board", systemImage: "rectangle.split.3x1") }
                .tag(PhoneTab.board)
            NavigationStack {
                TicketCalendarView()
                    .navigationTitle("Calendar")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .refreshesOnCategoryStyle()
            .tabItem { Label("Calendar", systemImage: "calendar") }
            .tag(PhoneTab.calendar)
            NavigationStack {
                StatsView().navigationTitle("Stats")
            }
            .refreshesOnCategoryStyle()
            .tabItem { Label("Stats", systemImage: "chart.bar") }
            .tag(PhoneTab.stats)
            PhoneSettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(PhoneTab.settings)
        }
    }
}
