import SwiftUI

struct PhoneSettingsView: View {
    @Environment(PhoneModel.self) private var model
    @AppStorage(RewardSettings.wantRatioKey, store: AppGroup.defaults) private var wantRatio = RewardSettings.defaultWantRatio
    @AppStorage(RewardSettings.funRatioKey, store: AppGroup.defaults) private var funRatio = RewardSettings.defaultFunRatio
    @AppStorage("doneShowsAll") private var doneShowsAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $wantRatio, in: 1...50) {
                        LabeledContent("Need points per Want", value: "\(wantRatio)")
                    }
                    Stepper(value: $funRatio, in: 1...50) {
                        LabeledContent("Need points per Fun", value: "\(funRatio)")
                    }
                } header: {
                    Text("Rewards")
                } footer: {
                    Text("Want and Fun counters are independent. Balances are recomputed from history, so changes apply retroactively. Ratios are set per device.")
                }

                Section {
                    Toggle("Keep all completed tickets in Done", isOn: $doneShowsAll)
                } header: {
                    Text("Board")
                } footer: {
                    Text("When off, Done shows this week and older tickets move to History.")
                }

                Section {
                    CategoryStyleSettings()
                } header: {
                    Text("Categories")
                } footer: {
                    Text("Pick an icon and color for Need, Want and Fun tickets. Distinct shapes keep them easy to tell apart in tinted widgets.")
                }

                Section {
                    ThemeColorSettings()
                } header: {
                    Text("Colors")
                } footer: {
                    Text("Greens from the logo by default. Tap a swatch to pick any color (Spectrum is the color wheel); it applies right away. ↺ puts back the default.")
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
            .onChange(of: wantRatio) { SharedStore.reloadWidgets() }
            .onChange(of: funRatio) { SharedStore.reloadWidgets() }
        }
    }
}
