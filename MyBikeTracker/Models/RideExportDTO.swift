//
//  RideExportDTO.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 06.03.2025.
//

import Foundation

/// A plain Codable representation of a Ride used for JSON export/import.
struct RideExportDTO: Codable, Identifiable {
    var id: UUID
    var startDate: Date
    var endDate: Date
    var duration: TimeInterval
    var distance: Double
    var averageSpeed: Double
    var maxSpeed: Double
    var route: [RouteCoordinate]
    var matchedRoute: [RouteCoordinate]?

    struct RouteCoordinate: Codable {
        var latitude: Double
        var longitude: Double
    }
}

// MARK: - Conversion helpers

extension RideExportDTO {
    /// Convert a Ride model to a DTO ready for JSON encoding.
    init(ride: Ride) {
        self.id = ride.id
        self.startDate = ride.startDate
        self.endDate = ride.endDate
        self.duration = ride.duration
        self.distance = ride.distance
        self.averageSpeed = ride.averageSpeed
        self.maxSpeed = ride.maxSpeed
        self.route = ride.route.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
        self.matchedRoute = ride.matchedRoute?.map { RouteCoordinate(latitude: $0.latitude, longitude: $0.longitude) }
    }
}
