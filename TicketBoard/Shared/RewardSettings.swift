import Foundation

/// Tunable reward ratios, stored in the App Group defaults so the widget sees them too.
struct RewardSettings: Equatable {
    static let wantRatioKey = "wantRatio"
    static let funRatioKey = "funRatio"
    static let defaultWantRatio = 4
    static let defaultFunRatio = 7
    /// Want and Fun rewards on or off. Off hides reward tickets and the meter but keeps their data.
    static let enabledKey = "rewardsEnabled"
    /// Whether the large widget shows the reward meter.
    static let largeWidgetShowsMeterKey = "widgetLargeShowsRewards"

    /// Points on tickets on or off. Off counts each finished Need ticket as 1.
    static let pointsEnabledKey = "pointsEnabled"

    static func isEnabled(_ defaults: UserDefaults = AppGroup.defaults) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static func pointsEnabled(_ defaults: UserDefaults = AppGroup.defaults) -> Bool {
        defaults.object(forKey: pointsEnabledKey) as? Bool ?? true
    }

    var wantRatio: Int
    var funRatio: Int
    var countsPoints: Bool

    init(wantRatio: Int = defaultWantRatio, funRatio: Int = defaultFunRatio, countsPoints: Bool = true) {
        self.wantRatio = max(1, wantRatio)
        self.funRatio = max(1, funRatio)
        self.countsPoints = countsPoints
    }

    /// What a finished Need ticket is worth toward rewards.
    func value(ofPoints points: Int) -> Int {
        countsPoints ? max(0, points) : 1
    }

    /// "need points" for a count, or "need tickets" while points are off.
    func needUnit(_ count: Int) -> String {
        "need \(countsPoints ? "point" : "ticket")\(count == 1 ? "" : "s")"
    }

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> RewardSettings {
        let want = defaults.integer(forKey: wantRatioKey)
        let fun = defaults.integer(forKey: funRatioKey)
        return RewardSettings(
            wantRatio: want > 0 ? want : defaultWantRatio,
            funRatio: fun > 0 ? fun : defaultFunRatio,
            countsPoints: pointsEnabled(defaults)
        )
    }

    func ratio(for kind: Category) -> Int {
        kind == .fun ? funRatio : wantRatio
    }
}
