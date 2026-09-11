import CoreGraphics
import CoreLocation

struct RideLineHit {
    let ride: Ride
    let coordinate: CLLocationCoordinate2D
}

enum RideLineHitTesting {
    /// Finger-sized hit slop in screen points.
    static let defaultMaxDistance: CGFloat = 32

    static func nearestRide(
        at screenPoint: CGPoint,
        rides: [Ride],
        convert: (CLLocationCoordinate2D) -> CGPoint?,
        maxDistance: CGFloat = defaultMaxDistance
    ) -> Ride? {
        nearestHit(at: screenPoint, rides: rides, convert: convert, maxDistance: maxDistance)?.ride
    }

    static func nearestHit(
        at screenPoint: CGPoint,
        rides: [Ride],
        convert: (CLLocationCoordinate2D) -> CGPoint?,
        maxDistance: CGFloat = defaultMaxDistance
    ) -> RideLineHit? {
        var bestHit: RideLineHit?
        var bestDistance = maxDistance

        for ride in rides {
            guard let match = closestPoint(from: screenPoint, ride: ride, convert: convert),
                  match.distance < bestDistance else { continue }
            bestDistance = match.distance
            bestHit = RideLineHit(ride: ride, coordinate: match.coordinate)
        }
        return bestHit
    }

    private static func closestPoint(
        from point: CGPoint,
        ride: Ride,
        convert: (CLLocationCoordinate2D) -> CGPoint?
    ) -> (distance: CGFloat, coordinate: CLLocationCoordinate2D)? {
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestCoordinate: CLLocationCoordinate2D?

        for segment in ride.displaySegments where segment.count > 1 {
            guard let match = closestPoint(from: point, coordinates: segment, convert: convert) else { continue }
            if match.distance < bestDistance {
                bestDistance = match.distance
                bestCoordinate = match.coordinate
                if bestDistance == 0 { break }
            }
        }

        guard let bestCoordinate else { return nil }
        return (bestDistance, bestCoordinate)
    }

    private static func closestPoint(
        from point: CGPoint,
        coordinates: [CLLocationCoordinate2D],
        convert: (CLLocationCoordinate2D) -> CGPoint?
    ) -> (distance: CGFloat, coordinate: CLLocationCoordinate2D)? {
        var previousCoordinate = coordinates[0]
        var previousPoint = convert(previousCoordinate)
        var bestDistance = CGFloat.greatestFiniteMagnitude
        var bestCoordinate = previousCoordinate

        for index in 1..<coordinates.count {
            let currentCoordinate = coordinates[index]
            let currentPoint = convert(currentCoordinate)
            if let start = previousPoint, let end = currentPoint {
                let match = closestPoint(from: point, start: start, end: end)
                if match.distance < bestDistance {
                    bestDistance = match.distance
                    bestCoordinate = interpolate(previousCoordinate, currentCoordinate, t: match.t)
                }
            }
            previousCoordinate = currentCoordinate
            previousPoint = currentPoint
        }

        return bestDistance == .greatestFiniteMagnitude
            ? nil
            : (bestDistance, bestCoordinate)
    }

    private static func closestPoint(
        from point: CGPoint,
        start: CGPoint,
        end: CGPoint
    ) -> (distance: CGFloat, t: CGFloat) {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared < 0.0001 {
            return (hypot(point.x - start.x, point.y - start.y), 0)
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return (hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy)), t)
    }

    private static func interpolate(
        _ start: CLLocationCoordinate2D,
        _ end: CLLocationCoordinate2D,
        t: CGFloat
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: start.latitude + (end.latitude - start.latitude) * Double(t),
            longitude: start.longitude + (end.longitude - start.longitude) * Double(t)
        )
    }
}
