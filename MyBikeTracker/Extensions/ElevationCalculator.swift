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
}
