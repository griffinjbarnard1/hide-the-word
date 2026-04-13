import Foundation

public enum AppRoute: String, Hashable, Codable, Sendable, Identifiable {
    case todaySession = "session/today"
    case verseSets = "sets"
    case library = "library"
    case journey = "journey"
    case settings = "settings"
    case plans = "plans"

    public var id: String { rawValue }
}

public enum AppRouteBuilder {
    public static func route(from url: URL) -> AppRoute? {
        guard url.scheme == "scripturememory" else { return nil }

        let rawRoute = url.host.map { host in
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? host : "\(host)/\(path)"
        } ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        return AppRoute(rawValue: rawRoute)
    }

    public static func url(for route: AppRoute) -> URL {
        URL(string: "scripturememory://\(route.rawValue)")!
    }

    public static func url(for route: AppRoute, setID: UUID) -> URL {
        var components = URLComponents(url: url(for: route), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "setID", value: setID.uuidString)
        ]
        return components?.url ?? url(for: route)
    }
}
