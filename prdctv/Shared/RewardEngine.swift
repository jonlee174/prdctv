import Foundation

/// Pure reward math. Balances are always derived from history, never stored,
/// so un-completing a ticket or editing its points corrects them automatically.
///
///     earned    = floor(needPointsDone / ratio)
///     available = earned - redeemed
///
/// Want and Fun accumulate independently from the same need points.
struct RewardEngine: Equatable {
    let settings: RewardSettings
    let needPointsDone: Int
    let redeemedWant: Int
    let redeemedFun: Int

    init(needPointsDone: Int, redeemedWant: Int, redeemedFun: Int, settings: RewardSettings = RewardSettings()) {
        self.settings = settings
        self.needPointsDone = max(0, needPointsDone)
        self.redeemedWant = redeemedWant
        self.redeemedFun = redeemedFun
    }

    init(tickets: [Ticket], redemptions: [Redemption], settings: RewardSettings = RewardSettings()) {
        self.init(
            needPointsDone: tickets
                .filter { $0.category == .need && $0.status == .done }
                .reduce(0) { $0 + settings.value(ofPoints: $1.points) },
            redeemedWant: redemptions.filter { $0.kind == .want }.count,
            redeemedFun: redemptions.filter { $0.kind == .fun }.count,
            settings: settings
        )
    }

    func earned(_ kind: Category) -> Int {
        needPointsDone / settings.ratio(for: kind)
    }

    func redeemed(_ kind: Category) -> Int {
        kind == .fun ? redeemedFun : redeemedWant
    }

    /// Can be negative if points were un-completed after a reward was spent.
    func available(_ kind: Category) -> Int {
        earned(kind) - redeemed(kind)
    }

    /// Points toward the next reward, e.g. 3 in "3/4 toward Want".
    func progress(_ kind: Category) -> Int {
        needPointsDone % settings.ratio(for: kind)
    }

    func fraction(_ kind: Category) -> Double {
        Double(progress(kind)) / Double(settings.ratio(for: kind))
    }

    func progressLabel(_ kind: Category) -> String {
        "\(progress(kind))/\(settings.ratio(for: kind)) toward \(kind.label)"
    }

    /// Need points still required before one reward of `kind` is available.
    func pointsToUnlock(_ kind: Category) -> Int {
        max(0, (redeemed(kind) + 1) * settings.ratio(for: kind) - needPointsDone)
    }

    func lockedMessage(_ kind: Category) -> String {
        let needed = pointsToUnlock(kind)
        return "Complete \(needed) more \(settings.needUnit(needed)) to earn a \(kind.label) reward."
    }

    var menuBarLabel: String {
        "\(available(.want))W · \(available(.fun))F"
    }

    var earnedWant: Int { earned(.want) }
    var earnedFun: Int { earned(.fun) }
    var availableWant: Int { available(.want) }
    var availableFun: Int { available(.fun) }
}

extension Ticket {
    /// A Want/Fun ticket is locked until a reward has been spent on it.
    func isLocked(redemptions: [Redemption]) -> Bool {
        guard category.isReward else { return false }
        return !redemptions.contains { $0.ticketID == id }
    }
}
