import Foundation
import MetricKit

enum AnalyticsEvent: String, CaseIterable {
    case appLaunch
    case rideStart
    case ridePause
    case rideResume
    case rideSave
    case rideDiscard
    case rideRestore
    case locationDenied
    case locationAuthorized
    case storeOpenFailed
    case storeSaveFailed
    case exportCompleted
    case importCompleted
    case healthKitSaveFailed
    case checkpointWritten
    case checkpointWriteFailed
    case reviewPrompted
}

final class ProductAnalytics: NSObject, MXMetricManagerSubscriber {
    static let shared = ProductAnalytics()

    struct Record: Codable, Identifiable {
        var id: UUID
        var name: String
        var date: Date
        var properties: [String: String]
    }

    private let maxRecords = 400
    private let recordsKey = "product_analytics_events"
    private let crashKey = "product_analytics_last_crash"
    private let queue = DispatchQueue(label: "product.analytics", qos: .utility)
    private var cached: [Record] = []

    private override init() {
        super.init()
        cached = loadRecords()
        MXMetricManager.shared.add(self)
    }

    func track(_ event: AnalyticsEvent, _ properties: [String: String] = [:]) {
        let record = Record(id: UUID(), name: event.rawValue, date: Date(), properties: properties)
        queue.async { [weak self] in
            guard let self else { return }
            self.cached.append(record)
            if self.cached.count > self.maxRecords {
                self.cached.removeFirst(self.cached.count - self.maxRecords)
            }
            self.persistLocked()
        }
    }

    func recentEvents(limit: Int = 40) -> [Record] {
        queue.sync { Array(cached.suffix(limit).reversed()) }
    }

    func countsByEvent() -> [String: Int] {
        queue.sync {
            Dictionary(grouping: cached, by: \.name).mapValues(\.count)
        }
    }

    var lastCrashSummary: String? {
        UserDefaults.standard.string(forKey: crashKey)
    }

    func didReceive(_ payloads: [MXMetricPayload]) {
        _ = payloads
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        let summary = payloads
            .flatMap { payload in
                (payload.crashDiagnostics ?? []).map { diagnostic in
                    let name = diagnostic.applicationVersion
                    let reason = diagnostic.terminationReason ?? "crash"
                    return "\(name): \(reason)"
                }
            }
            .joined(separator: "\n")
        if !summary.isEmpty {
            UserDefaults.standard.set(summary, forKey: crashKey)
        }
    }

    private func persistLocked() {
        guard let data = try? JSONEncoder().encode(cached) else { return }
        UserDefaults.standard.set(data, forKey: recordsKey)
    }

    private func loadRecords() -> [Record] {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([Record].self, from: data)
        else { return [] }
        return records
    }
}
