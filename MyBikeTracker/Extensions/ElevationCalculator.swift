import CoreLocation
import Foundation

struct ElevationSample: Identifiable {
    let id: Int
    let distance: Double
    let altitude: Double
}

enum ElevationCalculator {
    static let minimumVerticalAccuracy: CLLocationAccuracy = 20
    static let minimumStepMeters: Double = 1.0

    static func gain(from locations: [CLLocation]) -> Double {
        var total = 0.0
        var lastValid: Double?
        for location in locations {
            guard location.verticalAccuracy >= 0,
                  location.verticalAccuracy <= minimumVerticalAccuracy else { continue }
            if let previous = lastValid {
                let delta = location.altitude - previous
                if delta >= minimumStepMeters {
                    total += delta
                }
            }
            lastValid = location.altitude
        }
        return total
    }

    static func gain(from coordinates: [Ride.Coordinate]) -> Double {
        var total = 0.0
        var lastValid: Double?
        for point in coordinates {
            guard let altitude = point.altitude else { continue }
            if let previous = lastValid {
                let delta = altitude - previous
                if delta >= minimumStepMeters {
                    total += delta
                }
            }
            lastValid = altitude
        }
        return total
    }

    static func profile(from coordinates: [Ride.Coordinate]) -> [ElevationSample] {
        var distance = 0.0
        var lastLocation: CLLocation?
        var samples: [ElevationSample] = []

        for point in coordinates {
            let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
            if let previous = lastLocation {
                distance += location.distance(from: previous)
            }
            lastLocation = location
            if let altitude = point.altitude {
                samples.append(ElevationSample(id: samples.count, distance: distance, altitude: altitude))
            }
        }
        return samples
    }

    /// Visible Y range for a profile chart. Does not include sea level unless the ride is actually there.
    static func chartAltitudeDomain(from samples: [ElevationSample], minimumSpan: Double = 16) -> ClosedRange<Double>? {
        let altitudes = samples.map(\.altitude)
        guard let minAltitude = altitudes.min(), let maxAltitude = altitudes.max() else { return nil }
        let span = max(maxAltitude - minAltitude, minimumSpan)
        let padding = max(span * 0.18, 4)
        let mid = (minAltitude + maxAltitude) / 2
        return (mid - span / 2 - padding)...(mid + span / 2 + padding)
    }
}
