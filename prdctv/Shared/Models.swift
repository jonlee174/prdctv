import Foundation
import SwiftData

enum Category: String, Codable, CaseIterable, Identifiable {
    case need, want, fun

    var id: String { rawValue }

    var label: String {
        switch self {
        case .need: "Need"
        case .want: "Want"
        case .fun: "Fun"
        }
    }

    /// Glyph used alongside color so categories stay distinguishable in
    /// desaturated widget rendering modes.
    /// Current icon: the user's choice (Settings → Categories) or the default.
    var symbol: String {
        if let chosen = AppGroup.defaults.string(forKey: symbolKey), Self.symbolChoices.contains(chosen) {
            return chosen
        }
        return defaultSymbol
    }

    var defaultSymbol: String {
        switch self {
        case .need: "circle.fill"
        case .want: "diamond.fill"
        case .fun: "star.fill"
        }
    }

    // No dots in key names: SwiftUI can't observe dotted keys (see ThemeColorKey).
    var symbolKey: String { "category\(label)Symbol" }
    var colorKey: String { "category\(label)Color" }

    /// Icons offered in Settings. Solid shapes read best at glyph size and in the
    /// widget's desaturated modes.
    static let symbolChoices = [
        "circle.fill", "square.fill", "diamond.fill", "triangle.fill", "hexagon.fill", "seal.fill",
        "star.fill", "heart.fill", "bolt.fill", "flame.fill", "sparkles", "moon.fill",
        "sun.max.fill", "leaf.fill", "drop.fill", "flag.fill", "bookmark.fill", "tag.fill",
        "checkmark.seal.fill", "briefcase.fill", "book.fill", "graduationcap.fill", "hammer.fill", "house.fill",
        "cart.fill", "gift.fill", "gamecontroller.fill", "film.fill", "music.note", "paintpalette.fill",
        "cup.and.saucer.fill", "fork.knife", "sportscourt.fill", "figure.run", "airplane", "pawprint.fill",
    ]

    var isReward: Bool { self != .need }

    /// Categories in use, just Need while rewards are off.
    static func shown(rewardsEnabled: Bool = RewardSettings.isEnabled()) -> [Category] {
        rewardsEnabled ? allCases : [.need]
    }
}

enum Status: String, Codable, CaseIterable, Identifiable {
    case upNext, inProgress, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .upNext: "Up Next"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }

    var next: Status? {
        switch self {
        case .upNext: .inProgress
        case .inProgress: .done
        case .done: nil
        }
    }

    /// Moving a Want/Fun ticket into one of these columns means "starting" it,
    /// which costs a reward.
    var requiresUnlock: Bool { self == .inProgress || self == .done }
}

/// Allowed point values (Fibonacci).
enum PointScale {
    static let values = [1, 2, 3, 5, 8]
}

// Every stored property has a default so the schema stays CloudKit-compatible
// if sync is added later. Enums are stored as raw strings so they can be used
// in #Predicate.
@Model
final class Ticket {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var categoryRaw: String = Category.need.rawValue
    var points: Int = 1
    var statusRaw: String = Status.upNext.rawValue
    var sortIndex: Double = 0
    var createdAt: Date = Date()
    var completedAt: Date?
    var dueDate: Date?
    var tags: [String] = []
    /// Repeat count, 0 when the ticket doesn't repeat. When done, a copy goes to Up Next.
    var repeatEvery: Int = 0
    var repeatUnitRaw: String = RepeatUnit.day.rawValue
    /// Waiting on someone else. Shown on the board with a badge and left out of the widget.
    var onHold: Bool = false

    init(
        title: String,
        notes: String = "",
        category: Category = .need,
        points: Int = 1,
        status: Status = .upNext,
        sortIndex: Double = 0,
        dueDate: Date? = nil,
        tags: [String] = []
    ) {
        self.id = UUID()
        self.title = title
        self.notes = notes
        self.categoryRaw = category.rawValue
        self.points = points
        self.statusRaw = status.rawValue
        self.sortIndex = sortIndex
        self.createdAt = Date()
        self.completedAt = status == .done ? Date() : nil
        self.dueDate = dueDate
        self.tags = tags
    }

    var repeatRule: RepeatRule? {
        get { repeatEvery > 0 ? RepeatRule(every: repeatEvery, unit: RepeatUnit(rawValue: repeatUnitRaw) ?? .day) : nil }
        set {
            repeatEvery = newValue.map { max($0.every, 1) } ?? 0
            repeatUnitRaw = (newValue?.unit ?? .day).rawValue
        }
    }

    /// The Up Next copy made when a repeating ticket is done, due one interval later.
    func repeatCopy(sortIndex: Double, finishedAt finished: Date = Date(), calendar: Calendar = .current) -> Ticket? {
        guard let rule = repeatRule else { return nil }
        let copy = Ticket(title: title, notes: notes, category: category, points: points, status: .upNext,
                          sortIndex: sortIndex, dueDate: rule.nextDue(after: dueDate, finishedAt: finished, calendar: calendar),
                          tags: tags)
        copy.repeatRule = rule
        return copy
    }

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .need }
        set { categoryRaw = newValue.rawValue }
    }

    /// Setting status keeps `completedAt` in sync.
    var status: Status {
        get { Status(rawValue: statusRaw) ?? .upNext }
        set {
            let old = status
            statusRaw = newValue.rawValue
            if newValue == .done, old != .done { completedAt = Date() }
            if newValue != .done { completedAt = nil }
        }
    }
}

@Model
final class Redemption {
    var id: UUID = UUID()
    var kindRaw: String = Category.want.rawValue
    var redeemedAt: Date = Date()
    /// Which want/fun ticket it was spent on.
    var ticketID: UUID?

    init(kind: Category, ticketID: UUID?, redeemedAt: Date = Date()) {
        precondition(kind.isReward, "Only want/fun rewards can be redeemed")
        self.id = UUID()
        self.kindRaw = kind.rawValue
        self.redeemedAt = redeemedAt
        self.ticketID = ticketID
    }

    var kind: Category {
        get { Category(rawValue: kindRaw) ?? .want }
        set { kindRaw = newValue.rawValue }
    }
}
