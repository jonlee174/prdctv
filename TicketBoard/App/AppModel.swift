import AppKit
import Observation
import SwiftData
import SwiftUI

enum BoardMode: String, Hashable {
    case board, calendar
}

/// App-wide state: owns the SwiftData container and routes deep links and commands.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    /// `--demo`: in-memory store with sample tickets, for trying the app without touching real data.
    let store = StoreController(demo: CommandLine.arguments.contains("--demo"))
    private var pollTimer: Timer?

    var container: ModelContainer { store.container }
    /// Bumped when the container is replaced, so views re-create their queries.
    var generation: Int { store.generation }

    var selectedTicketID: UUID?
    /// Set to open the redemption sheet for a reward kind.
    var redeemKind: Category?
    /// Set to show the "which reward?" picker (from the widget's Redeem button).
    var showRedeemPicker = false
    var newTicketRequest: Status?
    var boardMode = BoardMode.board
    var showImport = false

    let quickAdd = QuickAddPanelController()

    private init() {}

    func refreshIfNeeded() {
        store.refreshIfNeeded()
    }

    func startWatchingWidgetWrites() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { AppModel.shared.refreshIfNeeded() }
        }
        // Desktop widget clicks don't necessarily activate the app, so also poll cheaply.
        pollTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { _ in
            MainActor.assumeIsolated { AppModel.shared.refreshIfNeeded() }
        }
    }

    func handle(_ url: URL) {
        refreshIfNeeded()
        switch DeepLink(url: url) {
        case .ticket(let id): selectedTicketID = id
        case .redeem: showRedeemPicker = RewardSettings.isEnabled()
        case .quickAdd:
            // Opening a URL activates the app and makes the board key, which would
            // immediately dismiss the panel; show it once activation settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.quickAdd.show() }
        case nil: break
        }
    }
}
