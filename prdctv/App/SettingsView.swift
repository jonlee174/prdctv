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
            Section("Rewards") {
                Toggle("Want and Fun rewards", isOn: $rewardsEnabled)
                Stepper(value: $wantRatio, in: 1...50) {
                    LabeledContent(pointsEnabled ? "Need points per Want" : "Need tickets per Want", value: "\(wantRatio)")
                }
                .disabled(!rewardsEnabled)
                Stepper(value: $funRatio, in: 1...50) {
                    LabeledContent(pointsEnabled ? "Need points per Fun" : "Need tickets per Fun", value: "\(funRatio)")
                }
                .disabled(!rewardsEnabled)
                Text("When off, the reward meter and Want and Fun tickets are hidden. The tickets are kept and come back when you turn rewards on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Want and Fun counters are independent: both accumulate from the same need points. Balances are recomputed from history, so changes apply retroactively.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Board") {
                Toggle("Points", isOn: $pointsEnabled)
                Text("When off, point values are hidden and each finished Need ticket counts as 1 toward rewards. Point values are kept.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Keep all completed tickets in Done", isOn: $doneShowsAll)
                Text("When off, Done shows this week and older tickets move to History.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Confetti when a ticket is done", isOn: $confetti)
            }

            Section {
                CategoryStyleSettings()
            } header: {
                Text("Categories")
            } footer: {
                Text("Pick an icon and color for Need, Want and Fun tickets.")
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

            Section {
                TagColorSettings()
            } header: {
                Text("Tags")
            } footer: {
                Text("Color tasks by tag gives each task its first tag's color, or green without a tag. Tag order sets how tag lanes and List by tag are ordered. Custom follows the arrows, and Soonest due date puts the tag with the next due task first. Each tag gets a color from its name. Click a swatch to choose another, and ↺ puts back the default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                WidgetSettings()
            } header: {
                Text("Widget")
            } footer: {
                Text("Due dates show the weekday for the coming week and the date after that. By tag lists open tickets under bold tag titles. By status lists them under In Progress and Up Next, each sorted by due date. Applies to every prdctv widget.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Add") {
                KeyboardShortcuts.Recorder("Global shortcut:", name: .quickAdd)
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
