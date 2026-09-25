import Foundation

enum AppGroup {
    /// Team-prefixed macOS App Group. Must match `APP_GROUP_ID` in project.yml.
    static let id = "TTM9BN6M53.com.jonathanlee.TicketBoard"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

enum DeepLink: Equatable {
    case ticket(UUID)
    case redeem
    case quickAdd

    static let scheme = "ticketboard"

    var url: URL {
        switch self {
        case .ticket(let id): URL(string: "\(Self.scheme)://ticket/\(id.uuidString)")!
        case .redeem: URL(string: "\(Self.scheme)://redeem")!
        case .quickAdd: URL(string: "\(Self.scheme)://quickadd")!
        }
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "ticket":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .ticket(id)
        case "redeem": self = .redeem
        case "quickadd": self = .quickAdd
        default: return nil
        }
    }
}
