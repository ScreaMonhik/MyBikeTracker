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
            coordinateCache.display = nil
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
            coordinateCache.display = nil
        }
    }

    /// Coordinates to draw on the map. Prefers the matched route when present.
    var displayCoordinates: [CLLocationCoordinate2D] {
        if let cached = coordinateCache.display { return cached }
        let coords: [CLLocationCoordinate2D]
        if let matched = matchedRoute, !matched.isEmpty {
            coords = matched.map(\.clLocationCoordinate2D)
        } else {
            coords = route.map(\.clLocationCoordinate2D)
        }
        coordinateCache.display = coords
        return coords
    }

    // MARK: - Вложенный тип координаты

    struct Coordinate: Codable {
        let latitude: Double
        let longitude: Double

        init(_ location: CLLocationCoordinate2D) {
            self.latitude = location.latitude
            self.longitude = location.longitude
        }

        var clLocationCoordinate2D: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
        matchedRoute: [CLLocationCoordinate2D]? = nil
    ) {
        self.id = UUID()
        self.startDate = startDate
        self.endDate = endDate
        self.duration = duration
        self.distance = distance
        self.averageSpeed = averageSpeed
        self.maxSpeed = maxSpeed

        // Инициализируем хранимые поля перед использованием сеттеров
        self.routeData = Data()
        self.matchedRouteData = nil

        // Кодируем маршруты через вычисляемые сеттеры
        self.route = route.map { Coordinate($0) }
        if let matched = matchedRoute {
            self.matchedRoute = matched.map { Coordinate($0) }
        }
    }
}

/// Decoded-route cache that is not itself an observed @Model property.
private final class RideCoordinateCache {
    var route: [Ride.Coordinate]?
    var matched: [Ride.Coordinate]?
    var display: [CLLocationCoordinate2D]?
}
