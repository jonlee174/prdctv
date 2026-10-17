import SwiftUI

struct PhoneSettingsView: View {
    @Environment(PhoneModel.self) private var model
    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    @AppStorage("doneShowsAll") private var doneShowsAll = false
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true
    @AppStorage(RewardSettings.pointsEnabledKey, store: AppGroup.defaults) private var pointsEnabled = true

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Want and Fun rewards", isOn: $rewardsEnabled)
                    Stepper(value: $wantRatio, in: 1...50) {
                        LabeledContent(pointsEnabled ? "Need points per Want" : "Need tickets per Want", value: "\(wantRatio)")
                    }
                    .disabled(!rewardsEnabled)
                    Stepper(value: $funRatio, in: 1...50) {
                        LabeledContent(pointsEnabled ? "Need points per Fun" : "Need tickets per Fun", value: "\(funRatio)")
                    }
                    .disabled(!rewardsEnabled)
                } header: {
                    Text("Rewards")
                } footer: {
                    Text("When off, the reward meter and Want and Fun tickets are hidden but kept. Want and Fun counters are independent. Balances are recomputed from history, so changes apply retroactively. Ratios are set per device.")
                }

                Section {
                    Toggle("Points", isOn: $pointsEnabled)
                    Toggle("Keep all completed tickets in Done", isOn: $doneShowsAll)
                } header: {
                    Text("Board")
                } footer: {
                    Text("With Points off, each finished Need ticket counts as 1 toward rewards and point values are hidden but kept. With Keep all off, Done shows this week and older tickets move to History.")
                }

                Section {
                    CategoryStyleSettings()
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Pick an icon and color for Need, Want and Fun tickets.")
                }

                Section {
                    ThemeColorSettings()
                } header: {
                    Text("Colors")
                } footer: {
                    Text("Greens from the logo by default. Tap a swatch to pick any color (Spectrum is the color wheel); it applies right away. ↺ puts back the default.")
                }

                Section {
                    TagColorSettings()
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Color tasks by tag gives each task its first tag's color, or green without a tag. Tag order sets how tag lanes and List by tag are ordered. Custom follows the arrows, and Soonest due date puts the tag with the next due task first. Each tag gets a color from its name. Tap a swatch to choose another, and ↺ puts back the default.")
                }

                Section {
                    WidgetSettings()
                } header: {
                    Text("Widget")
                } footer: {
                    Text("Due dates show the weekday for the coming week and the date after that. List by tag shows open tickets under bold tag titles instead of by column. Applies to every prdctv widget.")
                }

                Section("Appearance") {
                    AppearancePicker()
                }

                Section("Sync") {
                    if model.store.isDemo {
                        Label("Demo mode: sample data, not saved or synced", systemImage: "theatermasks")
                    } else {
                        Label("Tickets and rewards sync with your Mac through iCloud", systemImage: "icloud")
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
