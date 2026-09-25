import AppKit
import Observation
import SwiftData
import SwiftUI

/// App-wide state: owns the SwiftData container and routes deep links and commands.
@MainActor
@Observable
final class AppModel {
    static let shared = AppModel()

    private(set) var container: ModelContainer
    /// Bumped when the container is replaced, so views re-create their queries.
    private(set) var generation = 0
    private var loadedAt = Date()
    private var pollTimer: Timer?

    var selectedTicketID: UUID?
    /// Set to open the redemption sheet for a reward kind.
    var redeemKind: Category?
    /// Set to show the "which reward?" picker (from the widget's Redeem button).
    var showRedeemPicker = false
    var newTicketRequest: Status?
    var showImport = false

    let quickAdd = QuickAddPanelController()

    /// `--demo`: in-memory store with sample tickets, for trying the app without touching real data.
    let isDemo = CommandLine.arguments.contains("--demo")

    private init() {
        container = SharedStore.makeContainer(inMemory: isDemo)
        if isDemo { DemoData.seed(container.mainContext) }
    }

    /// SwiftData contexts don't see writes from the widget process, so swap in a
    /// fresh container whenever the widget has written since we last loaded.
    func refreshIfNeeded() {
        guard !isDemo, SharedStore.lastWidgetWrite > loadedAt else { return }
        container = SharedStore.makeContainer()
        loadedAt = Date()
        generation += 1
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
        case .redeem: showRedeemPicker = true
        case .quickAdd:
            // Opening a URL activates the app and makes the board key, which would
            // immediately dismiss the panel; show it once activation settles.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.quickAdd.show() }
        case nil: break
        }
    }
}
