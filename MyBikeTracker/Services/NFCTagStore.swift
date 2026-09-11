import Foundation

struct NFCTagStore {
    private let key = "nfc_registered_tags"

    func load() -> [NFCTagRecord] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([NFCTagRecord].self, from: data)) ?? []
    }

    func save(_ tags: [NFCTagRecord]) {
        guard let data = try? JSONEncoder().encode(tags) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
