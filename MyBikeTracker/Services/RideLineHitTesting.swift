import CoreGraphics
import CoreLocation

enum RideLineHitTesting {
    /// Finger-sized hit slop in screen points.
    static let defaultMaxDistance: CGFloat = 32

    static func nearestRide(
        at screenPoint: CGPoint,
        rides: [Ride],
        convert: (CLLocationCoordinate2D) -> CGPoint?,
        maxDistance: CGFloat = defaultMaxDistance
    ) -> Ride? {
        var bestRide: Ride?
        var bestDistance = maxDistance

        for ride in rides {
            let distance = minDistance(from: screenPoint, ride: ride, convert: convert)
            if distance < bestDistance {
                bestDistance = distance
                bestRide = ride
            }
        }
        return bestRide
    }

    private static func minDistance(
        from point: CGPoint,
        ride: Ride,
        convert: (CLLocationCoordinate2D) -> CGPoint?
    ) -> CGFloat {
        var minimum = CGFloat.greatestFiniteMagnitude
        for segment in ride.displaySegments where segment.count > 1 {
            minimum = min(minimum, distance(from: point, coordinates: segment, convert: convert))
            if minimum == 0 { return 0 }
        }
        return minimum
    }

    private static func distance(
        from point: CGPoint,
        coordinates: [CLLocationCoordinate2D],
        convert: (CLLocationCoordinate2D) -> CGPoint?
    ) -> CGFloat {
        var previous = convert(coordinates[0])
        var minimum = CGFloat.greatestFiniteMagnitude
        for index in 1..<coordinates.count {
            let current = convert(coordinates[index])
            if let start = previous, let end = current {
                minimum = min(minimum, distance(from: point, toSegmentFrom: start, to: end))
            }
            previous = current
        }
        return minimum
    }

    private static func distance(from point: CGPoint, toSegmentFrom start: CGPoint, to end: CGPoint) -> CGFloat {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared < 0.0001 {
            return hypot(point.x - start.x, point.y - start.y)
        }
        let t = max(0, min(1, ((point.x - start.x) * dx + (point.y - start.y) * dy) / lengthSquared))
        return hypot(point.x - (start.x + t * dx), point.y - (start.y + t * dy))
    }
}
