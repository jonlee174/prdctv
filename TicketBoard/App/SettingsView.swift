import KeyboardShortcuts
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    @AppStorage("doneShowsAll") private var doneShowsAll = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Rewards") {
                Stepper(value: $wantRatio, in: 1...50) {
                    LabeledContent("Need points per Want", value: "\(wantRatio)")
                }
                Stepper(value: $funRatio, in: 1...50) {
                    LabeledContent("Need points per Fun", value: "\(funRatio)")
                }
                Text("Want and Fun counters are independent: both accumulate from the same need points. Balances are recomputed from history, so changes apply retroactively.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Board") {
                Toggle("Keep all completed tickets in Done", isOn: $doneShowsAll)
                Text("When off, Done shows this week and older tickets move to History.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                CategoryStyleSettings()
            } header: {
                Text("Categories")
            } footer: {
                Text("Pick an icon and color for Need, Want and Fun tickets. Icons also tell categories apart in the widget when macOS fades it, so distinct shapes work best.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                ThemeColorSettings()
            } header: {
                Text("Colors")
            } footer: {
                Text("Greens from the logo by default. Click a swatch to choose any color from the color wheel; it applies right away. ↺ puts back the default. Column colors also tint the widget headings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Add") {
                KeyboardShortcuts.Recorder("Global shortcut:", name: .quickAdd)
            }

            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 800)
        .onChange(of: wantRatio) { SharedStore.reloadWidgets() }
        .onChange(of: funRatio) { SharedStore.reloadWidgets() }
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
