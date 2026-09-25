import Foundation

/// Tunable reward ratios, stored in the App Group defaults so the widget sees them too.
struct RewardSettings: Equatable {
    static let wantRatioKey = "wantRatio"
    static let funRatioKey = "funRatio"
    static let defaultWantRatio = 4
    static let defaultFunRatio = 7

    var wantRatio: Int
    var funRatio: Int

    init(wantRatio: Int = defaultWantRatio, funRatio: Int = defaultFunRatio) {
        self.wantRatio = max(1, wantRatio)
        self.funRatio = max(1, funRatio)
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> RewardSettings {
        let want = defaults.integer(forKey: wantRatioKey)
        let fun = defaults.integer(forKey: funRatioKey)
        return RewardSettings(
            wantRatio: want > 0 ? want : defaultWantRatio,
            funRatio: fun > 0 ? fun : defaultFunRatio
        )
    }

    func ratio(for kind: Category) -> Int {
        kind == .fun ? funRatio : wantRatio
    }
}
