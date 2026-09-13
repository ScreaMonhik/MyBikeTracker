import Foundation
import CoreLocation

struct RideCheckpoint: Codable, Equatable {
    var schemaVersion: Int = 1
    var startTime: Date
    var elapsedTime: TimeInterval
    var totalPausedTime: TimeInterval
    var pauseStartTime: Date?
    var isPaused: Bool
    var isAutoPaused: Bool
    var traveledDistance: Double
    var elevationGain: Double
    var maxSpeed: Double
    var averageSpeed: Double
    var selectedBikeId: String?
    var locations: [CheckpointLocation]
    var heartRateSum: Int
    var heartRateCount: Int
    var maxHeartRate: Int
    var cadenceSum: Double
    var cadenceCount: Int

    var averageHeartRate: Double {
        guard heartRateCount > 0 else { return 0 }
        return Double(heartRateSum) / Double(heartRateCount)
    }

    var averageCadence: Double {
        guard cadenceCount > 0 else { return 0 }
        return cadenceSum / Double(cadenceCount)
    }
}

struct CheckpointLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var timestamp: TimeInterval
    var speed: Double
    var course: Double
    var horizontalAccuracy: Double
    var verticalAccuracy: Double

    init(_ location: CLLocation) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        altitude = location.altitude
        timestamp = location.timestamp.timeIntervalSince1970
        speed = location.speed
        course = location.course
        horizontalAccuracy = location.horizontalAccuracy
        verticalAccuracy = location.verticalAccuracy
    }

    var clLocation: CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            verticalAccuracy: verticalAccuracy,
            course: course,
            speed: speed,
            timestamp: Date(timeIntervalSince1970: timestamp)
        )
    }
}

enum RideCheckpointStore {
    static let fileName = "live_ride_checkpoint.json"
    static let flagKey = "live_ride_checkpoint_present"

    static func save(_ checkpoint: RideCheckpoint) {
        guard let url = fileURL() else { return }
        do {
            let data = try JSONEncoder().encode(checkpoint)
            try data.write(to: url, options: .atomic)
            defaults?.set(true, forKey: flagKey)
        } catch {
            ProductAnalytics.shared.track(.checkpointWriteFailed, ["error": error.localizedDescription])
        }
    }

    static func load() -> RideCheckpoint? {
        guard let url = fileURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let checkpoint = try? JSONDecoder().decode(RideCheckpoint.self, from: data)
        else { return nil }
        return checkpoint
    }

    static func clear() {
        if let url = fileURL() {
            try? FileManager.default.removeItem(at: url)
        }
        defaults?.removeObject(forKey: flagKey)
    }

    static func fileURL() -> URL? {
        containerURL()?.appendingPathComponent(fileName)
    }

    private static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroup.id)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }
}

enum RidePersistencePolicy {
    static let minimumDistanceMeters: Double = 80
    static let minimumDurationSeconds: TimeInterval = 45

    static func isAccidental(distance: Double, duration: TimeInterval) -> Bool {
        distance < minimumDistanceMeters && duration < minimumDurationSeconds
    }
}
