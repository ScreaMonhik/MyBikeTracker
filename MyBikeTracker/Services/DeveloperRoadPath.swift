#if DEBUG
import CoreLocation
import MapKit

/// Builds a closed developer-ride path that follows MapKit cycling / walking / driving geometry.
enum DeveloperRoadPath {
    static func makeLoop(
        around origin: CLLocationCoordinate2D,
        stepMeters: Double
    ) async -> [CLLocationCoordinate2D] {
        let stops = await roadStops(from: origin)
        var waypoints = [origin] + stops
        waypoints.append(origin)

        let legs = await routeLegs(along: waypoints)
        var joined: [CLLocationCoordinate2D] = []
        for leg in legs {
            guard leg.count >= 2 else { continue }
            if joined.isEmpty {
                joined.append(contentsOf: leg)
                continue
            }
            if let last = joined.last, distance(last, leg[0]) > 25 {
                let bridge = await RoadPathService.routeOnRoads(from: last, to: leg[0])
                guard bridge.count >= 2 else { continue }
                joined.append(contentsOf: bridge.dropFirst())
            }
            joined.append(contentsOf: leg.dropFirst())
        }

        if let last = joined.last, distance(last, origin) > 25 {
            let home = await RoadPathService.routeOnRoads(from: last, to: origin)
            if home.count >= 2 {
                joined.append(contentsOf: home.dropFirst())
            }
        }

        let sampled = resample(joined, stepMeters: stepMeters)
        return sampled.count >= 8 ? sampled : []
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private static func roadStops(from origin: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D] {
        let searched = await nearbyPlaces(from: origin)
        if searched.count >= 3 {
            return searched
        }
        return geometricStreetCorners(from: origin)
    }

    private static func nearbyPlaces(from origin: CLLocationCoordinate2D) async -> [CLLocationCoordinate2D] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "cafe park store"
        request.resultTypes = .pointOfInterest
        request.region = MKCoordinateRegion(
            center: origin,
            latitudinalMeters: 1_000,
            longitudinalMeters: 1_000
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            return []
        }

        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        var buckets: [Int: (coordinate: CLLocationCoordinate2D, distance: CLLocationDistance)] = [:]

        for item in response.mapItems {
            let coordinate = item.placemark.coordinate
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let distance = location.distance(from: originLocation)
            guard distance >= 90, distance <= 850 else { continue }
            let quadrant = Int(bearing(from: origin, to: coordinate) / 90) % 4
            if let current = buckets[quadrant] {
                if distance > current.distance {
                    buckets[quadrant] = (coordinate, distance)
                }
            } else {
                buckets[quadrant] = (coordinate, distance)
            }
        }

        return (0..<4).compactMap { buckets[$0]?.coordinate }
    }

    private static func geometricStreetCorners(
        from origin: CLLocationCoordinate2D
    ) -> [CLLocationCoordinate2D] {
        [
            LocationService.offsetEastNorth(from: origin, east: 230, north: 170),
            LocationService.offsetEastNorth(from: origin, east: 250, north: -180),
            LocationService.offsetEastNorth(from: origin, east: -210, north: -200),
            LocationService.offsetEastNorth(from: origin, east: -230, north: 160)
        ]
    }

    private static func routeLegs(
        along waypoints: [CLLocationCoordinate2D]
    ) async -> [[CLLocationCoordinate2D]] {
        let count = max(waypoints.count - 1, 0)
        return await withTaskGroup(of: (Int, [CLLocationCoordinate2D]).self) { group in
            for index in 0..<count {
                let start = waypoints[index]
                let end = waypoints[index + 1]
                group.addTask {
                    (index, await RoadPathService.routeOnRoads(from: start, to: end))
                }
            }

            var legs = Array(repeating: [CLLocationCoordinate2D](), count: count)
            for await (index, coordinates) in group {
                legs[index] = coordinates
            }
            return legs
        }
    }

    static func resample(
        _ coordinates: [CLLocationCoordinate2D],
        stepMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let step = max(stepMeters, 2)
        guard coordinates.count >= 2 else { return coordinates }

        var result = [coordinates[0]]
        var leftover = 0.0
        for index in 1..<coordinates.count {
            let previous = coordinates[index - 1]
            let next = coordinates[index]
            let start = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
            let end = CLLocation(latitude: next.latitude, longitude: next.longitude)
            let segment = start.distance(from: end)
            guard segment > 0 else { continue }

            var consumed = 0.0
            while leftover + (segment - consumed) >= step {
                let need = step - leftover
                consumed += need
                let fraction = consumed / segment
                result.append(
                    CLLocationCoordinate2D(
                        latitude: previous.latitude + (next.latitude - previous.latitude) * fraction,
                        longitude: previous.longitude + (next.longitude - previous.longitude) * fraction
                    )
                )
                leftover = 0
            }
            leftover += segment - consumed
        }
        return result
    }

    private static func bearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return (degrees + 360).truncatingRemainder(dividingBy: 360)
    }
}
#endif
