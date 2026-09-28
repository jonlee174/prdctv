import Charts
import SwiftData
import SwiftUI

/// Pure stat calculations over completed need tickets.
struct BoardStats {
    struct Week: Identifiable {
        let start: Date
        let points: Int
        var id: Date { start }
    }

    struct RewardPoint: Identifiable {
        let date: Date
        let count: Int
        let series: String
        var id: String { "\(series)-\(date.timeIntervalSince1970)-\(count)" }
    }

    let completions: [(date: Date, points: Int)]
    let calendar: Calendar

    /// With `settings.countsPoints` off, each completion is worth 1.
    init(tickets: [Ticket], settings: RewardSettings = RewardSettings(), calendar: Calendar = .current) {
        self.calendar = calendar
        completions = tickets
            .filter { $0.category == .need && $0.status == .done }
            .compactMap { t in t.completedAt.map { ($0, settings.value(ofPoints: t.points)) } }
            .sorted { $0.date < $1.date }
    }

    func weeks(count: Int, now: Date = Date()) -> [Week] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start else { return [] }
        return (0..<count).reversed().compactMap { offset in
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { return nil }
            let points = completions.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.points }
            return Week(start: start, points: points)
        }
    }

    private var activeDays: Set<Date> {
        Set(completions.map { calendar.startOfDay(for: $0.date) })
    }

    /// Consecutive days with at least one completed need ticket, ending today
    /// (or yesterday, so the streak doesn't read 0 before today's first completion).
    func currentStreak(now: Date = Date()) -> Int {
        let days = activeDays
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) { day = calendar.date(byAdding: .day, value: -1, to: day)! }
        var streak = 0
        while days.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    var longestStreak: Int {
        let days = activeDays.sorted()
        var best = 0, run = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day { run += 1 } else { run = 1 }
            best = max(best, run)
            previous = day
        }
        return best
    }

    /// Cumulative earned rewards over time (steps whenever a completion crosses a multiple of the ratio).
    func earnedSeries(_ kind: Category, settings: RewardSettings) -> [RewardPoint] {
        var total = 0, earned = 0
        var points: [RewardPoint] = []
        for c in completions {
            total += c.points
            let now = total / settings.ratio(for: kind)
            if now != earned {
                earned = now
                points.append(RewardPoint(date: c.date, count: earned, series: "Earned"))
            }
        }
        return points
    }
}

struct StatsView: View {
    @Query private var tickets: [Ticket]
    @Query(sort: \Redemption.redeemedAt) private var redemptions: [Redemption]
    var rewardSettings = StoredRewardSettings()
    @State private var rewardKind = Category.want
    @AppStorage(RewardSettings.enabledKey, store: AppGroup.defaults) private var rewardsEnabled = true

    private var settings: RewardSettings { rewardSettings.value }

    var body: some View {
        let stats = BoardStats(tickets: tickets, settings: settings)
        let unit = settings.countsPoints ? "need pts" : "need tickets"
        let weeks = stats.weeks(count: 12)
        let engine = RewardEngine(tickets: tickets, redemptions: redemptions, settings: settings)

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    tile("Current streak", "\(stats.currentStreak())", unit: "days")
                    tile("Longest streak", "\(stats.longestStreak)", unit: "days")
                    tile("This week", "\(weeks.last?.points ?? 0)", unit: unit)
                    tile("All time", "\(engine.needPointsDone)", unit: unit)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(settings.countsPoints ? "Need points per week" : "Need tickets per week").font(.headline)
                    Chart(weeks) { week in
                        BarMark(
                            x: .value("Week", week.start, unit: .weekOfYear),
                            y: .value("Points", week.points)
                        )
                        .foregroundStyle(Category.need.color.gradient)
                        .cornerRadius(Radius.tiny)
                    }
                    .chartXAxis {
                        AxisMarks(values: .stride(by: .weekOfYear, count: 2)) {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .frame(height: 180)
                }

                if rewardsEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Rewards earned vs. redeemed").font(.headline)
                            Spacer()
                            Picker("Reward", selection: $rewardKind) {
                                Text("Want").tag(Category.want)
                                Text("Fun").tag(Category.fun)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 140)
                        }
                        let series = rewardSeries(stats: stats)
                        if series.isEmpty {
                            Text("No rewards yet.").foregroundStyle(.secondary).frame(height: 160)
                        } else {
                            Chart(series) { point in
                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Count", point.count)
                                )
                                .interpolationMethod(.stepEnd)
                                .foregroundStyle(by: .value("Series", point.series))
                            }
                            .chartForegroundStyleScale([
                                "Earned": rewardKind.color,
                                "Redeemed": Color.secondary,
                            ])
                            .frame(height: 180)
                        }
                        Text("\(engine.earned(rewardKind)) earned · \(engine.redeemed(rewardKind)) redeemed · \(engine.available(rewardKind)) available")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Redemption history").font(.headline)
                        if redemptions.isEmpty {
                            Text("Nothing redeemed yet.").foregroundStyle(.secondary)
                        }
                        ForEach(redemptions.reversed().prefix(20)) { r in
                            HStack {
                                Image(systemName: r.kind.symbol).foregroundStyle(r.kind.color).font(.caption)
                                Text(title(for: r))
                                Spacer()
                                Text(r.redeemedAt.formatted(date: .abbreviated, time: .shortened))
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                }
            }
            .padding(24)
        }
    }

    private func rewardSeries(stats: BoardStats) -> [BoardStats.RewardPoint] {
        var redeemed = 0
        let redeemedSeries = redemptions.filter { $0.kind == rewardKind }.map { r -> BoardStats.RewardPoint in
            redeemed += 1
            return .init(date: r.redeemedAt, count: redeemed, series: "Redeemed")
        }
        var all = stats.earnedSeries(rewardKind, settings: settings) + redeemedSeries
        // Extend both lines to now so the current level is visible.
        for name in ["Earned", "Redeemed"] {
            if let last = all.last(where: { $0.series == name }) {
                all.append(.init(date: Date(), count: last.count, series: name))
            }
        }
        return all
    }

    private func title(for redemption: Redemption) -> String {
        guard let id = redemption.ticketID else { return "\(redemption.kind.label) · off-board" }
        return tickets.first { $0.id == id }?.title ?? "\(redemption.kind.label) · deleted ticket"
    }

    private func tile(_ title: String, _ value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value).font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                Text(unit).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Radius.medium).fill(Color.primary.opacity(0.05)))
    }
}
