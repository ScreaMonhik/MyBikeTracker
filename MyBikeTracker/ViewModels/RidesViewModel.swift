//
//  RidesViewModel.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 23.05.2025.
//

import Foundation
import SwiftData
import CoreLocation
import UIKit

struct WeekSummary {
    var distance: Double
    var duration: TimeInterval
    var rideCount: Int
    var elevationGain: Double

    static let empty = WeekSummary(distance: 0, duration: 0, rideCount: 0, elevationGain: 0)
}

@MainActor
final class RidesViewModel: ObservableObject {
    @Published var rides: [Ride] = []
    @Published var bikes: [Bike] = []
    @Published var journals: [DayJournal] = []
    /// Bumps when a ride line color changes so the map redraws.
    @Published private(set) var routeStyleRevision = 0
    @Published var lastSaveError: String?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadAll()
    }

    // MARK: - Load

    func loadAll() {
        loadRides()
        loadBikes()
        loadJournals()
    }

    func loadRides() {
        let descriptor = FetchDescriptor<Ride>(
            sortBy: [SortDescriptor(\.startDate, order: .reverse)]
        )
        do {
            rides = try modelContext.fetch(descriptor)
            lastSaveError = nil
        } catch {
            lastSaveError = error.localizedDescription
            rides = []
        }
        WidgetDataService.shared.sync(rides: rides)
    }

    func loadBikes() {
        let descriptor = FetchDescriptor<Bike>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        bikes = (try? modelContext.fetch(descriptor)) ?? []
    }

    func loadJournals() {
        let descriptor = FetchDescriptor<DayJournal>(
            sortBy: [SortDescriptor(\.dayKey, order: .reverse)]
        )
        journals = (try? modelContext.fetch(descriptor)) ?? []
    }

    // MARK: - Weekly stats

    func weekSummary(containing date: Date, weekOffset: Int = 0) -> WeekSummary {
        let calendar = Calendar.current
        guard let week = calendar.dateInterval(of: .weekOfYear, for: date),
              let start = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: week.start),
              let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)
        else { return .empty }

        let inWeek = rides.filter { $0.startDate >= start && $0.startDate < end }
        return WeekSummary(
            distance: inWeek.reduce(0) { $0 + $1.distance },
            duration: inWeek.reduce(0) { $0 + $1.duration },
            rideCount: inWeek.count,
            elevationGain: inWeek.reduce(0) { $0 + $1.resolvedElevationGain }
        )
    }

    var thisWeek: WeekSummary { weekSummary(containing: Date()) }
    var lastWeek: WeekSummary { weekSummary(containing: Date(), weekOffset: -1) }

    // MARK: - Ride CRUD

    func addRide(_ ride: Ride) {
        modelContext.insert(ride)
        save()
        rides.insert(ride, at: 0)
        if let bikeId = ride.bikeId {
            applyOdometer(bikeId: bikeId, delta: ride.distance)
        }
        WidgetDataService.shared.sync(rides: rides)
    }

    func updateRideLineColor(_ ride: Ride, hex: String?) {
        ride.lineColorHex = hex
        save()
        routeStyleRevision += 1
    }

    func applyMatchedRoute(_ ride: Ride, coordinates: [CLLocationCoordinate2D]) {
        guard !coordinates.isEmpty else { return }
        ride.matchedRoute = coordinates.map { Ride.Coordinate($0) }
        save()
        WidgetDataService.shared.sync(rides: rides)
    }

    func deleteRide(at offsets: IndexSet) {
        let removed = offsets.sorted(by: >).map { rides.remove(at: $0) }
        for ride in removed {
            if let bikeId = ride.bikeId {
                applyOdometer(bikeId: bikeId, delta: -ride.distance)
            }
            modelContext.delete(ride)
        }
        save()
        WidgetDataService.shared.sync(rides: rides)
    }

    // MARK: - Garage

    func addBike(name: String, odometerMeters: Double = 0, chainIntervalMeters: Double = 400_000) {
        let bike = Bike(
            name: name,
            odometerMeters: odometerMeters,
            chainIntervalMeters: chainIntervalMeters,
            metersAtLastChainService: odometerMeters
        )
        modelContext.insert(bike)
        save()
        bikes.append(bike)
        if UserDefaults.standard.string(forKey: PreferenceKey.selectedBikeId)?.isEmpty != false {
            UserDefaults.standard.set(bike.id.uuidString, forKey: PreferenceKey.selectedBikeId)
        }
    }

    func deleteBike(_ bike: Bike) {
        if UserDefaults.standard.string(forKey: PreferenceKey.selectedBikeId) == bike.id.uuidString {
            UserDefaults.standard.set("", forKey: PreferenceKey.selectedBikeId)
        }
        modelContext.delete(bike)
        save()
        bikes.removeAll { $0.id == bike.id }
    }

    func resetChain(for bike: Bike) {
        bike.metersAtLastChainService = bike.odometerMeters
        save()
    }

    func applyOdometer(bikeId: UUID, delta: Double) {
        guard let bike = bikes.first(where: { $0.id == bikeId }) else { return }
        bike.odometerMeters = max(0, bike.odometerMeters + delta)
        save()
    }

    var chainDueBikes: [Bike] {
        bikes.filter(\.isChainDue)
    }

    func bike(for ride: Ride) -> Bike? {
        guard let bikeId = ride.bikeId else { return nil }
        return bikes.first { $0.id == bikeId }
    }

    // MARK: - Day journal

    func journal(for date: Date) -> DayJournal? {
        let key = Calendar.current.startOfDay(for: date)
        return journals.first { Calendar.current.isDate($0.dayKey, inSameDayAs: key) }
    }

    @discardableResult
    func journalOrCreate(for date: Date) -> DayJournal {
        if let existing = journal(for: date) { return existing }
        let entry = DayJournal(dayKey: Calendar.current.startOfDay(for: date))
        modelContext.insert(entry)
        save()
        journals.insert(entry, at: 0)
        return entry
    }

    func updateNote(_ note: String, for date: Date) {
        let entry = journalOrCreate(for: date)
        entry.note = note
        save()
    }

    func setPhoto(_ image: UIImage?, for date: Date) {
        let entry = journalOrCreate(for: date)
        if let fileName = entry.photoFileName {
            let url = photosDirectory.appendingPathComponent(fileName)
            try? FileManager.default.removeItem(at: url)
            entry.photoFileName = nil
        }
        if let image, let data = compressedJPEG(from: image) {
            let fileName = "\(UUID().uuidString).jpg"
            let url = photosDirectory.appendingPathComponent(fileName)
            try? data.write(to: url, options: .atomic)
            entry.photoFileName = fileName
        }
        save()
    }

    func photo(for date: Date) -> UIImage? {
        guard let fileName = journal(for: date)?.photoFileName else { return nil }
        let url = photosDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private var photosDirectory: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DayPhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func compressedJPEG(from image: UIImage) -> Data? {
        let maxSide: CGFloat = 1600
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        let renderSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: renderSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: renderSize))
        }
        return scaled.jpegData(compressionQuality: 0.8)
    }

    // MARK: - Export

    func exportData() throws -> Data {
        try encodeBackup(includePhotos: true)
    }

    func encodeBackup(includePhotos: Bool) throws -> Data {
        let backup = AppBackupDTO(
            version: 2,
            exportedAt: Date(),
            rides: rides.map { RideExportDTO(ride: $0) },
            bikes: bikes.map { BikeExportDTO(bike: $0) },
            journals: journals.map { journal in
                let photo = includePhotos ? jpegData(for: journal) : nil
                return JournalExportDTO(journal: journal, photoJPEG: photo)
            }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    // MARK: - Import

    @discardableResult
    func importRides(from data: Data) throws -> Int {
        try importBackup(from: data).rides
    }

    @discardableResult
    func importBackup(from data: Data) throws -> ImportSummary {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let backup = try? decoder.decode(AppBackupDTO.self, from: data) {
            let bikesImported = importBikes(backup.bikes)
            let ridesImported = importRideDTOs(backup.rides, shouldApplyOdometer: false)
            let journalsImported = importJournals(backup.journals)
            if bikesImported + ridesImported + journalsImported > 0 {
                save()
                loadAll()
            }
            let summary = ImportSummary(rides: ridesImported, bikes: bikesImported, journals: journalsImported)
            ProductAnalytics.shared.track(.importCompleted, ["rides": "\(summary.rides)"])
            return summary
        }

        let dtos = try decoder.decode([RideExportDTO].self, from: data)
        let ridesImported = importRideDTOs(dtos, shouldApplyOdometer: true)
        if ridesImported > 0 {
            save()
            loadAll()
        }
        ProductAnalytics.shared.track(.importCompleted, ["rides": "\(ridesImported)"])
        return ImportSummary(rides: ridesImported, bikes: 0, journals: 0)
    }

    // MARK: - Private

    @discardableResult
    private func save() -> Bool {
        do {
            try modelContext.save()
            lastSaveError = nil
            return true
        } catch {
            lastSaveError = error.localizedDescription
            ProductAnalytics.shared.track(.storeSaveFailed, ["error": error.localizedDescription])
            return false
        }
    }

    private func importBikes(_ dtos: [BikeExportDTO]) -> Int {
        let existing = Set(bikes.map(\.id))
        var count = 0
        for dto in dtos where !existing.contains(dto.id) {
            let bike = Bike(
                name: dto.name,
                odometerMeters: dto.odometerMeters,
                chainIntervalMeters: dto.chainIntervalMeters,
                metersAtLastChainService: dto.metersAtLastChainService
            )
            bike.id = dto.id
            bike.createdAt = dto.createdAt
            modelContext.insert(bike)
            bikes.append(bike)
            count += 1
        }
        return count
    }

    private func importRideDTOs(_ dtos: [RideExportDTO], shouldApplyOdometer: Bool) -> Int {
        let existingIDs = Set(rides.map(\.id))
        var imported: [Ride] = []

        for dto in dtos {
            guard !existingIDs.contains(dto.id) else { continue }
            let ride = makeRide(from: dto)
            modelContext.insert(ride)
            imported.append(ride)
        }

        if shouldApplyOdometer {
            for ride in imported {
                if let bikeId = ride.bikeId {
                    applyOdometer(bikeId: bikeId, delta: ride.distance)
                }
            }
        }
        return imported.count
    }

    private func importJournals(_ dtos: [JournalExportDTO]) -> Int {
        var count = 0
        for dto in dtos {
            let entry = journalOrCreate(for: dto.dayKey)
            if !dto.note.isEmpty {
                entry.note = dto.note
            }
            if let base64 = dto.photoJPEGBase64, let data = Data(base64Encoded: base64), let image = UIImage(data: data) {
                setPhoto(image, for: dto.dayKey)
            }
            count += 1
        }
        return count
    }

    private func makeRide(from dto: RideExportDTO) -> Ride {
        let routeCoords = dto.route.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let matchedCoords = dto.matchedRoute?.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        let altitudes = dto.route.map(\.altitude)
        let ride = Ride(
            route: routeCoords,
            startDate: dto.startDate,
            endDate: dto.endDate,
            distance: dto.distance,
            averageSpeed: dto.averageSpeed,
            maxSpeed: dto.maxSpeed,
            duration: dto.duration,
            matchedRoute: matchedCoords,
            elevationGain: dto.elevationGain ?? 0,
            bikeId: dto.bikeId,
            altitudes: altitudes,
            averageHeartRate: dto.averageHeartRate ?? 0,
            maxHeartRate: dto.maxHeartRate ?? 0,
            averageCadence: dto.averageCadence ?? 0
        )
        ride.id = dto.id
        ride.lineColorHex = dto.lineColorHex
        ride.route = dto.route.map {
            Ride.Coordinate(
                CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude),
                altitude: $0.altitude,
                timestamp: $0.timestamp,
                speed: $0.speed
            )
        }
        return ride
    }

    private func jpegData(for journal: DayJournal) -> Data? {
        guard let fileName = journal.photoFileName else { return nil }
        let url = photosDirectory.appendingPathComponent(fileName)
        return try? Data(contentsOf: url)
    }
}
