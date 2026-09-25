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
    var symbol: String {
        switch self {
        case .need: "circle.fill"
        case .want: "diamond.fill"
        case .fun: "star.fill"
        }
    }

    var isReward: Bool { self != .need }
}

enum Status: String, Codable, CaseIterable, Identifiable {
    case backlog, upNext, inProgress, done

    var id: String { rawValue }

    var label: String {
        switch self {
        case .backlog: "Backlog"
        case .upNext: "Up Next"
        case .inProgress: "In Progress"
        case .done: "Done"
        }
    }

    var next: Status? {
        switch self {
        case .backlog: .upNext
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
    var statusRaw: String = Status.backlog.rawValue
    var sortIndex: Double = 0
    var createdAt: Date = Date()
    var completedAt: Date?
    var dueDate: Date?
    var tags: [String] = []

    init(
        title: String,
        notes: String = "",
        category: Category = .need,
        points: Int = 1,
        status: Status = .backlog,
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

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .need }
        set { categoryRaw = newValue.rawValue }
    }

    /// Setting status keeps `completedAt` in sync.
    var status: Status {
        get { Status(rawValue: statusRaw) ?? .backlog }
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
