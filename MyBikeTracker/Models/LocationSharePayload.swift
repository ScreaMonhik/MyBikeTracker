import Foundation

struct LocationSharePayload: Identifiable {
    let id = UUID()
    let text: String
    let url: URL
}
