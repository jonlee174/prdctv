import SwiftUI

struct PhoneSettingsView: View {
    @Environment(PhoneModel.self) private var model
    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    @AppStorage("doneShowsAll") private var doneShowsAll = false
    @AppStorage(Confetti.enabledKey) private var confetti = true
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true

    var body: some View {
        NavigationStack {
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
                    Text("Turning rewards off hides Want and Fun tickets without deleting them.")
                }

                Section {
                    Toggle("Points", isOn: $pointsEnabled)
                    Toggle("Keep all completed tickets in Done", isOn: $doneShowsAll)
                    Toggle("Confetti when a ticket is done", isOn: $confetti)
                } header: {
                    Text("Board")
                } footer: {
                    Text("Without points, each finished Need ticket counts as 1. Older tickets move to History unless Keep all is on.")
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
                    Text("Tap a swatch to change a color, and ↺ to restore the default.")
                }

                Section {
                    TagColorSettings()
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Custom order follows the arrows beside each tag.")
                }

                Section {
                    WidgetSettings()
                } header: {
                    Text("Widget")
                } footer: {
                    Text("Applies to every prdctv widget.")
                }

                Section("Appearance") {
                    AppearancePicker()
                }

                Section("Sync") {
                    if model.store.isDemo {
                        Label("Demo mode, so nothing is saved or synced", systemImage: "theatermasks")
                    } else {
                        Label("Syncs through iCloud", systemImage: "icloud")
                    }
                }
            }
            .navigationTitle("Settings")
            .onChange(of: rewardsEnabled) { SharedStore.reloadWidgets() }
            .onChange(of: pointsEnabled) { SharedStore.reloadWidgets() }
            .onChange(of: wantRatio) { SharedStore.reloadWidgets() }
            .onChange(of: funRatio) { SharedStore.reloadWidgets() }
        }
    }
}
