import CoreLocation
import SwiftData
import XCTest
@testable import MyBikeTracker

final class RidePersistenceTests: XCTestCase {
    func testAccidentalRideThreshold() {
        XCTAssertTrue(RidePersistencePolicy.isAccidental(distance: 20, duration: 10))
        XCTAssertFalse(RidePersistencePolicy.isAccidental(distance: 5_000, duration: 10))
        XCTAssertFalse(RidePersistencePolicy.isAccidental(distance: 20, duration: 600))
    }

    func testCheckpointRoundTripPreservesPoints() throws {
        let start = Date()
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
            altitude: 168,
            horizontalAccuracy: 4,
            verticalAccuracy: 3,
            course: 90,
            speed: 6,
            timestamp: start
        )
        let checkpoint = RideCheckpoint(
            startTime: start,
            elapsedTime: 120,
            totalPausedTime: 15,
            pauseStartTime: nil,
            isPaused: false,
            isAutoPaused: false,
            traveledDistance: 420,
            elevationGain: 12,
            maxSpeed: 28,
            averageSpeed: 18,
            selectedBikeId: nil,
            locations: [CheckpointLocation(location)],
            heartRateSum: 280,
            heartRateCount: 2,
            maxHeartRate: 148,
            cadenceSum: 170,
            cadenceCount: 2
        )

        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(RideCheckpoint.self, from: data)
        XCTAssertEqual(decoded.locations.count, 1)
        XCTAssertEqual(decoded.averageHeartRate, 140, accuracy: 0.01)
        XCTAssertEqual(decoded.locations[0].latitude, 50.45, accuracy: 0.0001)
        XCTAssertEqual(decoded.elapsedTime, 120, accuracy: 0.01)
    }

    @MainActor
    func testImportSkipsExistingUUIDAndAppliesOdometerForLegacyRides() throws {
        let schema = Schema([Ride.self, Bike.self, DayJournal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let viewModel = RidesViewModel(modelContext: container.mainContext)

        let bike = Bike(name: "Steel", odometerMeters: 0)
        viewModel.addBike(name: bike.name)
        let storedBike = try XCTUnwrap(viewModel.bikes.first)

        let rideID = UUID()
        let dto = RideExportDTO(
            id: rideID,
            startDate: Date().addingTimeInterval(-3600),
            endDate: Date(),
            duration: 1800,
            distance: 8_000,
            averageSpeed: 16,
            maxSpeed: 32,
            elevationGain: 40,
            bikeId: storedBike.id,
            lineColorHex: nil,
            averageHeartRate: 132,
            maxHeartRate: 164,
            averageCadence: 82,
            route: [
                .init(latitude: 50.45, longitude: 30.52, altitude: 168, timestamp: Date().timeIntervalSince1970, speed: 5)
            ],
            matchedRoute: nil
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode([dto])

        let first = try viewModel.importRides(from: data)
        XCTAssertEqual(first, 1)
        XCTAssertEqual(viewModel.rides.first?.id, rideID)
        XCTAssertEqual(viewModel.bikes.first?.odometerMeters ?? 0, 8_000, accuracy: 0.5)

        let second = try viewModel.importRides(from: data)
        XCTAssertEqual(second, 0)
        XCTAssertEqual(viewModel.rides.count, 1)
        XCTAssertEqual(viewModel.bikes.first?.odometerMeters ?? 0, 8_000, accuracy: 0.5)
    }

    func testYearlyMilesConversion() {
        let miles = RideFormatters.yearlyDistanceValue(kilometers: 100, system: .imperial)
        XCTAssertEqual(miles, "62.1")
    }

    func testCalorieEstimateUsesHeartRateWhenPresent() {
        let noHR = HealthKitService.estimatedKilocalories(
            distanceMeters: 10_000,
            duration: 1800,
            averageHeartRate: 0
        )
        let withHR = HealthKitService.estimatedKilocalories(
            distanceMeters: 10_000,
            duration: 1800,
            averageHeartRate: 160
        )
        XCTAssertGreaterThan(noHR, 0)
        XCTAssertGreaterThan(withHR, noHR)
    }
}
