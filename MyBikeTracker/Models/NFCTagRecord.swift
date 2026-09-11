import Foundation

enum NFCTagAction: String, Codable, CaseIterable, Identifiable {
    case toggleRide
    case startRide
    case stopRide

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .toggleRide: return "nfc_action_toggle_ride"
        case .startRide: return "nfc_action_start_ride"
        case .stopRide: return "nfc_action_stop_ride"
        }
    }

    var descriptionKey: String {
        switch self {
        case .toggleRide: return "nfc_action_toggle_ride_description"
        case .startRide: return "nfc_action_start_ride_description"
        case .stopRide: return "nfc_action_stop_ride_description"
        }
    }
}

struct NFCTagRecord: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String
    var action: NFCTagAction
    var createdAt: Date
    var tagUID: String?

    static let urlScheme = "mybiketracker"
    static let urlHost = "nfc"

    static func url(for id: UUID) -> URL {
        URL(string: "\(urlScheme)://\(urlHost)/\(id.uuidString)")!
    }

    static func isAppURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == urlScheme && url.host?.lowercased() == urlHost
    }

    static func id(from url: URL) -> UUID? {
        guard isAppURL(url) else { return nil }

        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let uuid = UUID(uuidString: path) {
            return uuid
        }

        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        if let value = items?.first(where: { $0.name == "id" })?.value {
            return UUID(uuidString: value)
        }

        return nil
    }
}

struct NFCActivation: Equatable {
    let token = UUID()
    let tag: NFCTagRecord
}
