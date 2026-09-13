import Foundation
import SwiftData

struct PersistenceIssue: Identifiable, Equatable {
    enum Kind: Equatable {
        case openedFromBackup
        case ephemeralFallback
    }

    let id = UUID()
    let kind: Kind
    let message: String
    let backupDirectory: URL?
}

struct PersistenceOpenResult {
    let container: ModelContainer
    let issue: PersistenceIssue?
}

enum PersistenceController {
    static let schema = Schema([Ride.self, Bike.self, DayJournal.self])

    static func open() -> PersistenceOpenResult {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            let container = try ModelContainer(for: schema, configurations: [configuration])
            return PersistenceOpenResult(container: container, issue: nil)
        } catch {
            let backup = backupStoreFiles(around: configuration.url)
            ProductAnalytics.shared.track(.storeOpenFailed, ["error": error.localizedDescription])

            if let recovered = try? ModelContainer(for: schema, configurations: [configuration]) {
                return PersistenceOpenResult(
                    container: recovered,
                    issue: PersistenceIssue(
                        kind: .openedFromBackup,
                        message: error.localizedDescription,
                        backupDirectory: backup
                    )
                )
            }

            let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let ephemeral = try! ModelContainer(for: schema, configurations: [memory])
            return PersistenceOpenResult(
                container: ephemeral,
                issue: PersistenceIssue(
                    kind: .ephemeralFallback,
                    message: error.localizedDescription,
                    backupDirectory: backup
                )
            )
        }
    }

    @discardableResult
    static func backupStoreFiles(around storeURL: URL) -> URL? {
        let fileManager = FileManager.default
        let backupsRoot = applicationSupportDirectory.appendingPathComponent("StoreBackups", isDirectory: true)
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let destination = backupsRoot.appendingPathComponent(stamp, isDirectory: true)

        do {
            try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
            for url in sidecarURLs(for: storeURL) where fileManager.fileExists(atPath: url.path) {
                let target = destination.appendingPathComponent(url.lastPathComponent)
                if fileManager.fileExists(atPath: target.path) {
                    try fileManager.removeItem(at: target)
                }
                try fileManager.copyItem(at: url, to: target)
            }
            return destination
        } catch {
            return nil
        }
    }

    static func latestBackupDirectory() -> URL? {
        let root = applicationSupportDirectory.appendingPathComponent("StoreBackups", isDirectory: true)
        let contents = try? FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        )
        return contents?.max {
            let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return left < right
        }
    }

    private static func sidecarURLs(for storeURL: URL) -> [URL] {
        [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-shm"),
            URL(fileURLWithPath: storeURL.path + "-wal")
        ]
    }

    private static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }
}
