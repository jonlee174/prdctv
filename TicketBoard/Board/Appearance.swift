import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Light or dark mode for the app, following the system unless the user picks one. Stored per device.
enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    static let storageKey = "appearance"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    static var current: AppAppearance {
        UserDefaults.standard.string(forKey: storageKey).flatMap(AppAppearance.init) ?? .system
    }

    /// Sets it app wide, since `preferredColorScheme` misses panels, the menu bar popover and sheets.
    @MainActor
    func apply() {
        #if os(macOS)
        switch self {
        case .system: NSApp.appearance = nil
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        }
        #elseif os(iOS)
        let style: UIUserInterfaceStyle = switch self {
        case .system: .unspecified
        case .light: .light
        case .dark: .dark
        }
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            scene.windows.forEach { $0.overrideUserInterfaceStyle = style }
        }
        #endif
    }
}

/// The Appearance picker for Settings.
struct AppearancePicker: View {
    @AppStorage(AppAppearance.storageKey) private var appearance = AppAppearance.system

    var body: some View {
        Picker("Appearance", selection: $appearance) {
            ForEach(AppAppearance.allCases) { Text($0.label).tag($0) }
        }
        .onChange(of: appearance) { _, new in new.apply() }
    }
}
