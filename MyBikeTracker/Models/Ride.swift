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

    // MARK: - Удобные вычисляемые свойства (не хранятся в БД)

    var route: [Coordinate] {
        get { (try? JSONDecoder().decode([Coordinate].self, from: routeData)) ?? [] }
        set { routeData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    var matchedRoute: [Coordinate]? {
        get {
            guard let data = matchedRouteData else { return nil }
            return try? JSONDecoder().decode([Coordinate].self, from: data)
        }
        set {
            matchedRouteData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
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
