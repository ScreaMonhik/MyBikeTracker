//
//  RidesViewModel.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 23.05.2025.
//

import Foundation
import SwiftData
import CoreLocation

@MainActor
final class RidesViewModel: ObservableObject {
    @Published var rides: [Ride] = []

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadRides()
    }

    // MARK: - CRUD

    func loadRides() {
        let descriptor = FetchDescriptor<Ride>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        rides = (try? modelContext.fetch(descriptor)) ?? []
        WidgetDataService.shared.sync(rides: rides)
    }

    func addRide(_ ride: Ride) {
        modelContext.insert(ride)
        save()
        loadRides()
    }

    func deleteRide(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(rides[index])
        }
        save()
        loadRides()
    }

    // MARK: - Export

    /// Encodes all rides into JSON Data ready for sharing.
    func exportData() throws -> Data {
        let dtos = rides.map { RideExportDTO(ride: $0) }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(dtos)
    }

    // MARK: - Import

    /// Decodes rides from JSON Data, inserts those not already present (by UUID).
    /// Returns the number of newly imported rides.
    @discardableResult
    func importRides(from data: Data) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let dtos = try decoder.decode([RideExportDTO].self, from: data)

        let existingIDs = Set(rides.map { $0.id })
        var importedCount = 0

        for dto in dtos {
            guard !existingIDs.contains(dto.id) else { continue }

            let routeCoords = dto.route.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }
            let matchedCoords = dto.matchedRoute?.map {
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
            }

            let ride = Ride(
                route: routeCoords,
                startDate: dto.startDate,
                endDate: dto.endDate,
                distance: dto.distance,
                averageSpeed: dto.averageSpeed,
                maxSpeed: dto.maxSpeed,
                duration: dto.duration,
                matchedRoute: matchedCoords
            )
            // Preserve the original UUID so re-import stays idempotent
            ride.id = dto.id
            modelContext.insert(ride)
            importedCount += 1
        }

        if importedCount > 0 {
            save()
            loadRides()
        }
        return importedCount
    }

    // MARK: - Private

    private func save() {
        try? modelContext.save()
    }
}
