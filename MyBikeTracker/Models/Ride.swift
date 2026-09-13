//
//  Ride.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import Foundation
import CoreLocation
import SwiftData

@Model
final class Ride {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var distance: Double      // метры
    var averageSpeed: Double  // км/ч
    var maxSpeed: Double      // км/ч
    var elevationGain: Double = 0
    var averageHeartRate: Double = 0
    var maxHeartRate: Int = 0
    var averageCadence: Double = 0
    var bikeId: UUID?
    /// Custom map line color as `#RRGGBB`. `nil` uses the default map color from Settings.
    var lineColorHex: String? = nil

    // MARK: - Хранение маршрутов как JSON Data
    // SwiftData не поддерживает [CustomCodableStruct] напрямую,
    // поэтому сериализуем в Data и предоставляем удобные вычисляемые свойства.

    /// Сырой маршрут в виде JSON-сериализованных Coordinate
    var routeData: Data = Data()

    /// Скорректированный маршрут (опционально)
    var matchedRouteData: Data? = nil

    /// Reference-type cache so decode hits do not assign @Model properties
    /// (that would publish from inside view updates).
    @Transient private var coordinateCache = RideCoordinateCache()

    // MARK: - Удобные вычисляемые свойства (не хранятся в БД)

    var route: [Coordinate] {
        get {
            if let cached = coordinateCache.route { return cached }
            let decoded = (try? JSONDecoder().decode([Coordinate].self, from: routeData)) ?? []
            coordinateCache.route = decoded
            return decoded
        }
        set {
            routeData = (try? JSONEncoder().encode(newValue)) ?? Data()
            coordinateCache.route = newValue
            coordinateCache.displaySegments = nil
            coordinateCache.speedSlices = nil
        }
    }

    var matchedRoute: [Coordinate]? {
        get {
            if let cached = coordinateCache.matched { return cached }
            guard let data = matchedRouteData else { return nil }
            let decoded = try? JSONDecoder().decode([Coordinate].self, from: data)
            coordinateCache.matched = decoded
            return decoded
        }
        set {
            matchedRouteData = newValue.flatMap { try? JSONEncoder().encode($0) }
            coordinateCache.matched = newValue
            coordinateCache.displaySegments = nil
            coordinateCache.speedSlices = nil
        }
    }

    /// Coordinates to draw on the map. Prefers the matched route when present.
    var displayCoordinates: [CLLocationCoordinate2D] {
        displaySegments.flatMap { $0 }
    }

    /// Separate polylines so a GPS / network blackout is never joined by a straight cut.
    var displaySegments: [[CLLocationCoordinate2D]] {
        if let cached = coordinateCache.displaySegments { return cached }
        let segments: [[CLLocationCoordinate2D]]
        if let matched = matchedRoute, !matched.isEmpty {
            segments = RideTrackGeometry.coordinateSegments(
                matched.map(\.clLocationCoordinate2D),
                maxJump: RideTrackGeometry.matchedGapDistance
            )
        } else {
            segments = RideTrackGeometry.coordinateSegments(
                route.map(\.clLocationCoordinate2D),
                maxJump: RideTrackGeometry.liveGapDistance
            )
        }
        coordinateCache.displaySegments = segments
        return segments
    }

    /// Heatmap pieces from raw GPS (speed or inferred from timestamps).
    var speedColoredSlices: [SpeedColoredSlice] {
        if let cached = coordinateCache.speedSlices { return cached }
        let points = route
        let hasMotion = points.contains { ($0.timestamp ?? 0) > 0 || ($0.speed ?? -1) >= 0 }
        let slices: [SpeedColoredSlice]
        if hasMotion, points.count > 1 {
            slices = RideTrackGeometry.speedColoredSlices(
                gpsSegments: RideTrackGeometry.segments(from: points.map(\.clLocation))
            )
        } else {
            slices = []
        }
        coordinateCache.speedSlices = slices
        return slices
    }

    // MARK: - Вложенный тип координаты

    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double
        var altitude: Double?
        var timestamp: TimeInterval?
        /// Meters per second when GPS reported a valid speed.
        var speed: Double?

        init(
            _ location: CLLocationCoordinate2D,
            altitude: Double? = nil,
            timestamp: TimeInterval? = nil,
            speed: Double? = nil
        ) {
            self.latitude = location.latitude
            self.longitude = location.longitude
            self.altitude = altitude
            self.timestamp = timestamp
            self.speed = speed
        }

        init(_ location: CLLocation) {
            self.latitude = location.coordinate.latitude
            self.longitude = location.coordinate.longitude
            if location.verticalAccuracy >= 0 && location.verticalAccuracy <= 20 {
                self.altitude = location.altitude
            } else {
                self.altitude = nil
            }
            self.timestamp = location.timestamp.timeIntervalSince1970
            self.speed = location.speed >= 0 ? location.speed : nil
        }

        var clLocationCoordinate2D: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        var clLocation: CLLocation {
            CLLocation(
                coordinate: clLocationCoordinate2D,
                altitude: altitude ?? 0,
                horizontalAccuracy: 15,
                verticalAccuracy: altitude == nil ? -1 : 10,
                course: -1,
                speed: speed ?? -1,
                timestamp: timestamp.map { Date(timeIntervalSince1970: $0) } ?? .distantPast
            )
        }
    }

    // MARK: - Инициализатор

    init(
        route: [CLLocationCoordinate2D],
        startDate: Date,
        endDate: Date,
        distance: Double,
        averageSpeed: Double,
        maxSpeed: Double = 0,
        duration: TimeInterval,
        matchedRoute: [CLLocationCoordinate2D]? = nil,
        elevationGain: Double = 0,
        bikeId: UUID? = nil,
        altitudes: [Double?] = [],
        averageHeartRate: Double = 0,
        maxHeartRate: Int = 0,
        averageCadence: Double = 0
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed
        self.elevationGain = elevationGain
        self.averageHeartRate = averageHeartRate
        self.maxHeartRate = maxHeartRate
        self.averageCadence = averageCadence
        self.bikeId = bikeId

        // Инициализируем хранимые поля перед использованием сеттеров
        self.routeData = Data()
        self.matchedRouteData = nil

        if altitudes.isEmpty {
            self.route = route.map { Coordinate($0) }
        } else {
            self.route = zip(route, altitudes).map { Coordinate($0, altitude: $1) }
            if route.count > altitudes.count {
                self.route.append(contentsOf: route[altitudes.count...].map { Coordinate($0) })
            }
        }
        if let matched = matchedRoute {
            self.matchedRoute = matched.map { Coordinate($0) }
        }
    }

    convenience init(
        locations: [CLLocation],
        startDate: Date,
        endDate: Date,
        distance: Double,
        averageSpeed: Double,
        maxSpeed: Double = 0,
        duration: TimeInterval,
        matchedRoute: [CLLocationCoordinate2D]? = nil,
        elevationGain: Double? = nil,
        bikeId: UUID? = nil,
        averageHeartRate: Double = 0,
        maxHeartRate: Int = 0,
        averageCadence: Double = 0
    ) {
        self.init(
            route: locations.map(\.coordinate),
            startDate: startDate,
            endDate: endDate,
            distance: distance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            duration: duration,
            matchedRoute: matchedRoute,
            elevationGain: elevationGain ?? ElevationCalculator.gain(from: locations),
            bikeId: bikeId,
            averageHeartRate: averageHeartRate,
            maxHeartRate: maxHeartRate,
            averageCadence: averageCadence
        )
        self.route = locations.map { Coordinate($0) }
    }

    var resolvedElevationGain: Double {
        if elevationGain > 0 { return elevationGain }
        return ElevationCalculator.gain(from: route)
    }

    var elevationProfile: [ElevationSample] {
        ElevationCalculator.profile(from: route)
    }

    var hasCustomLineColor: Bool { lineColorHex != nil }

    /// Speed heatmap unless this ride has a custom solid color.
    var usesSpeedHeatmapLine: Bool {
        guard !hasCustomLineColor else { return false }
        return speedColoredSlices.contains { $0.coordinates.count > 1 }
    }
}

/// Decoded-route cache that is not itself an observed @Model property.
private final class RideCoordinateCache {
    var route: [Ride.Coordinate]?
    var matched: [Ride.Coordinate]?
    var displaySegments: [[CLLocationCoordinate2D]]?
    var speedSlices: [SpeedColoredSlice]?
}
