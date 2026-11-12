import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    @AppStorage("doneShowsAll") private var doneShowsAll = false
    @AppStorage(Confetti.enabledKey) private var confetti = true
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Want and Fun rewards", isOn: $rewardsEnabled)
                if rewardsEnabled {
                    Stepper(value: $wantRatio, in: 1...50) {
                        LabeledContent(pointsEnabled ? "Need points per Want" : "Need tickets per Want", value: "\(wantRatio)")
                    }
                    Stepper(value: $funRatio, in: 1...50) {
                        LabeledContent(pointsEnabled ? "Need points per Fun" : "Need tickets per Fun", value: "\(funRatio)")
                    }
                }
            } header: {
                Text("Rewards")
            } footer: {
                caption("Turning rewards off hides Want and Fun tickets without deleting them.")
            }

            Section {
                Toggle("Points", isOn: $pointsEnabled)
                Toggle("Keep all completed tickets in Done", isOn: $doneShowsAll)
                Toggle("Confetti when a ticket is done", isOn: $confetti)
            } header: {
                Text("Board")
            } footer: {
                caption("Without points, each finished Need ticket counts as 1. Older tickets move to History unless Keep all is on.")
            }

            if rewardsEnabled {
                Section("Categories") {
                    CategoryStyleSettings()
                }
            }

            Section {
                ThemeColorSettings()
            } header: {
                Text("Colors")
            } footer: {
                caption("Click a swatch to change a color, and ↺ to restore the default.")
            }

            Section {
                TagColorSettings()
            } header: {
                Text("Tags")
            } footer: {
                caption("Custom order follows the arrows beside each tag.")
            }

            Section {
                WidgetSettings()
            } header: {
                Text("Widget")
            } footer: {
                caption("Applies to every prdctv widget.")
            }

            Section("Quick Add") {
                KeyboardShortcuts.Recorder("Global shortcut", name: .quickAdd)
            }

            Section("General") {
                AppearancePicker()
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 800)
        .onChange(of: rewardsEnabled) { SharedStore.reloadWidgets() }
        .onChange(of: pointsEnabled) { SharedStore.reloadWidgets() }
        .onChange(of: wantRatio) { SharedStore.reloadWidgets() }
        .onChange(of: funRatio) { SharedStore.reloadWidgets() }
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError = nil
        } catch {
            loginError = error.localizedDescription
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
