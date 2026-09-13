import CoreLocation

/// Splits a ride track when GPS / network drops, so we never draw a teleport line.
enum RideTrackGeometry {
    /// Consecutive GPS points farther than this start a new segment.
    static let liveGapDistance: CLLocationDistance = 80
    /// Matched road geometry can have longer vertices; only split huge jumps.
    static let matchedGapDistance: CLLocationDistance = 220
    /// Don't ask directions for a multi-kilometre blackout.
    static let maxFillDistance: CLLocationDistance = 4_000
    static let maxImpliedSpeedMps: Double = 22
    static let minGapTime: TimeInterval = 20
    static let minGapDistanceWithTime: CLLocationDistance = 40

    static func isDiscontinuity(from start: CLLocation, to end: CLLocation) -> Bool {
        let distance = end.distance(from: start)
        let dt = end.timestamp.timeIntervalSince(start.timestamp)
        if distance >= liveGapDistance { return true }
        if dt >= minGapTime && distance >= minGapDistanceWithTime { return true }
        if dt > 0.5 && (distance / dt) > maxImpliedSpeedMps { return true }
        return false
    }

    static func segments(from locations: [CLLocation]) -> [[CLLocation]] {
        guard !locations.isEmpty else { return [] }
        var result: [[CLLocation]] = []
        var current: [CLLocation] = [locations[0]]
        for index in 1..<locations.count {
            let previous = locations[index - 1]
            let next = locations[index]
            if isDiscontinuity(from: previous, to: next) {
                result.append(current)
                current = [next]
            } else {
                current.append(next)
            }
        }
        result.append(current)
        return result
    }

    static func coordinateSegments(
        _ coordinates: [CLLocationCoordinate2D],
        maxJump: CLLocationDistance
    ) -> [[CLLocationCoordinate2D]] {
        guard !coordinates.isEmpty else { return [] }
        var result: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = [coordinates[0]]
        for index in 1..<coordinates.count {
            let previous = coordinates[index - 1]
            let next = coordinates[index]
            let distance = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
            if distance >= maxJump {
                result.append(current)
                current = [next]
            } else {
                current.append(next)
            }
        }
        result.append(current)
        return result
    }

    static func traveledDistance(from locations: [CLLocation]) -> Double {
        segments(from: locations).reduce(0) { $0 + polylineDistance($1) }
    }

    static func polylineDistance(_ locations: [CLLocation]) -> Double {
        guard locations.count > 1 else { return 0 }
        var distance: Double = 0
        for index in 1..<locations.count {
            distance += locations[index].distance(from: locations[index - 1])
        }
        return distance
    }

    static func polylineDistance(_ coordinates: [CLLocationCoordinate2D]) -> Double {
        guard coordinates.count > 1 else { return 0 }
        var distance: Double = 0
        for index in 1..<coordinates.count {
            let start = CLLocation(latitude: coordinates[index - 1].latitude, longitude: coordinates[index - 1].longitude)
            let end = CLLocation(latitude: coordinates[index].latitude, longitude: coordinates[index].longitude)
            distance += end.distance(from: start)
        }
        return distance
    }

    static func gapKey(from start: CLLocation, to end: CLLocation) -> String {
        let slat = (start.coordinate.latitude * 1e5).rounded()
        let slon = (start.coordinate.longitude * 1e5).rounded()
        let elat = (end.coordinate.latitude * 1e5).rounded()
        let elon = (end.coordinate.longitude * 1e5).rounded()
        return "\(slat),\(slon)->\(elat),\(elon)"
    }

    static func isPlausibleFill(distance: CLLocationDistance, duration: TimeInterval) -> Bool {
        guard distance > 0, duration > 1 else { return false }
        let speed = distance / duration
        return speed >= 0.7 && speed <= maxImpliedSpeedMps
    }

    /// GPS pieces plus any road-fill connectors that were recovered after the network returned.
    static func stitchedDisplay(
        gpsSegments: [[CLLocation]],
        fills: [String: [CLLocationCoordinate2D]]
    ) -> [[CLLocationCoordinate2D]] {
        var result: [[CLLocationCoordinate2D]] = []
        for (index, segment) in gpsSegments.enumerated() {
            let coords = segment.map(\.coordinate)
            if coords.count > 1 {
                result.append(coords)
            }
            if index + 1 < gpsSegments.count,
               let start = segment.last,
               let end = gpsSegments[index + 1].first,
               let fill = fills[gapKey(from: start, to: end)],
               fill.count > 1 {
                result.append(fill)
            }
        }
        return result
    }

    /// Speed-colored pieces of the live GPS track, including road-fill connectors.
    static func speedColoredSlices(
        gpsSegments: [[CLLocation]],
        fills: [String: [CLLocationCoordinate2D]] = [:]
    ) -> [SpeedColoredSlice] {
        var builder = SpeedSliceBuilder()
        for (index, segment) in gpsSegments.enumerated() {
            appendGPSSegment(segment, into: &builder)
            guard index + 1 < gpsSegments.count,
                  let start = segment.last,
                  let end = gpsSegments[index + 1].first,
                  let fill = fills[gapKey(from: start, to: end)],
                  fill.count > 1 else { continue }
            let duration = end.timestamp.timeIntervalSince(start.timestamp)
            let distance = polylineDistance(fill)
            let kmh: Double
            if duration > 0.5 {
                kmh = (distance / duration) * 3.6
            } else {
                kmh = speedKmh(from: start, to: end)
            }
            builder.append(coordinates: fill, speedKmh: kmh)
        }
        return builder.finish()
    }

    static func speedKmh(from start: CLLocation, to end: CLLocation) -> Double {
        let samples = [start.speed, end.speed].filter { $0 >= 0 }
        if !samples.isEmpty {
            return samples.reduce(0, +) / Double(samples.count) * 3.6
        }
        let duration = end.timestamp.timeIntervalSince(start.timestamp)
        guard duration > 0.2 else { return 0 }
        return (end.distance(from: start) / duration) * 3.6
    }

    private static func appendGPSSegment(_ segment: [CLLocation], into builder: inout SpeedSliceBuilder) {
        guard segment.count > 1 else { return }
        for index in 1..<segment.count {
            let start = segment[index - 1]
            let end = segment[index]
            builder.append(
                coordinates: [start.coordinate, end.coordinate],
                speedKmh: speedKmh(from: start, to: end)
            )
        }
    }
}

private struct SpeedSliceBuilder {
    private var slices: [SpeedColoredSlice] = []
    private var current: [CLLocationCoordinate2D] = []
    private var currentBand: Int?
    private var speedSum = 0.0
    private var speedCount = 0

    mutating func append(coordinates: [CLLocationCoordinate2D], speedKmh: Double) {
        guard coordinates.count >= 2 else { return }
        guard RideTrackGeometry.polylineDistance(coordinates) > 0.4 else { return }
        let band = SpeedHeatmap.band(forKmh: speedKmh)
        if currentBand == band, let last = current.last {
            if sameCoordinate(coordinates[0], last) {
                current.append(contentsOf: coordinates.dropFirst())
            } else {
                current.append(contentsOf: coordinates)
            }
            speedSum += speedKmh
            speedCount += 1
            return
        }
        flush()
        current = coordinates
        currentBand = band
        speedSum = speedKmh
        speedCount = 1
    }

    mutating func finish() -> [SpeedColoredSlice] {
        flush()
        return slices
    }

    private mutating func flush() {
        defer {
            current = []
            currentBand = nil
            speedSum = 0
            speedCount = 0
        }
        guard current.count > 1, speedCount > 0, let band = currentBand else { return }
        slices.append(
            SpeedColoredSlice(
                id: "\(slices.count)-\(sliceID(coordinates: current, band: band))",
                coordinates: current,
                speedKmh: speedSum / Double(speedCount)
            )
        )
    }

    private func sliceID(coordinates: [CLLocationCoordinate2D], band: Int) -> String {
        guard coordinates.count >= 2 else { return "empty-\(band)" }
        let first = coordinates[0]
        let second = coordinates[1]
        return String(
            format: "%.5f,%.5f,%.5f,%.5f,%d",
            first.latitude,
            first.longitude,
            second.latitude,
            second.longitude,
            band
        )
    }

    private func sameCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 1e-9 && abs(a.longitude - b.longitude) < 1e-9
    }
}
