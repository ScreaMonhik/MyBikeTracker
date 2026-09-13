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
    var elevationGain: Double?
    var bikeId: UUID?
    var lineColorHex: String?
    var route: [RouteCoordinate]
    var matchedRoute: [RouteCoordinate]?

    struct RouteCoordinate: Codable {
        var latitude: Double
        var longitude: Double
        var altitude: Double?
        var timestamp: TimeInterval?
        var speed: Double?
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
        self.elevationGain = ride.elevationGain
        self.bikeId = ride.bikeId
        self.lineColorHex = ride.lineColorHex
        self.route = ride.route.map {
            RouteCoordinate(
                latitude: $0.latitude,
                longitude: $0.longitude,
                altitude: $0.altitude,
                timestamp: $0.timestamp,
                speed: $0.speed
            )
        }
        self.matchedRoute = ride.matchedRoute?.map {
            RouteCoordinate(
                latitude: $0.latitude,
                longitude: $0.longitude,
                altitude: $0.altitude,
                timestamp: $0.timestamp,
                speed: $0.speed
            )
        }
    }
}
