import CoreLocation
import SwiftData
import XCTest
@testable import MyBikeTracker

final class PaceAndUnitsTests: XCTestCase {
    func testWeeklyGoalDisplayRoundTripsThroughMiles() {
        let kilometers = 50.0
        let miles = RideFormatters.weeklyGoalDisplay(kilometers: kilometers, system: .imperial)
        XCTAssertEqual(miles, kilometers * 1000 / RideFormatters.metersPerMile, accuracy: 0.0001)

        let back = RideFormatters.weeklyGoalKilometers(fromDisplay: miles, system: .imperial)
        XCTAssertEqual(back, kilometers, accuracy: 0.0001)

        let milesLabel = RideFormatters.distance(meters: kilometers * 1000, system: .imperial)
        let kmLabel = RideFormatters.distance(meters: kilometers * 1000, system: .metric)
        XCTAssertNotEqual(milesLabel, kmLabel)
        XCTAssertEqual(RideFormatters.distanceValue(meters: kilometers * 1000, system: .imperial), String(format: "%.2f", miles))
    }

    func testDefaultPaceScaleBandsMatchLegacyStops() {
        let scale = PaceScale.default
        XCTAssertEqual(scale.band(forKmh: 0), .slow)
        XCTAssertEqual(scale.band(forKmh: 11.9), .slow)
        XCTAssertEqual(scale.band(forKmh: 12), .medium)
        XCTAssertEqual(scale.band(forKmh: 27.9), .medium)
        XCTAssertEqual(scale.band(forKmh: 28), .fast)
    }

    func testCustomBikeScaleShiftsBands() {
        let scale = PaceScale(slowMaxKmh: 20, mediumMaxKmh: 30).sanitized
        XCTAssertEqual(scale.band(forKmh: 19.9), .slow)
        XCTAssertEqual(scale.band(forKmh: 20), .medium)
        XCTAssertEqual(scale.band(forKmh: 30), .fast)
    }

    func testPaceShareIsAllSlowWhenEverySliceIsSlow() {
        let slices = [
            SpeedColoredSlice(
                id: "a",
                coordinates: [
                    CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
                    CLLocationCoordinate2D(latitude: 50.451, longitude: 30.52)
                ],
                speedKmh: 8
            ),
            SpeedColoredSlice(
                id: "b",
                coordinates: [
                    CLLocationCoordinate2D(latitude: 50.451, longitude: 30.52),
                    CLLocationCoordinate2D(latitude: 50.452, longitude: 30.52)
                ],
                speedKmh: 10
            )
        ]
        let shares = RidePaceShare.fractions(slices: slices, scale: .default)
        XCTAssertEqual(shares.first { $0.0 == .slow }?.1 ?? 0, 1, accuracy: 0.001)
        XCTAssertEqual(shares.first { $0.0 == .fast }?.1 ?? 0, 0, accuracy: 0.001)
    }

    func testPaceShareWeightsLongerSlowStretch() {
        let slow = SpeedColoredSlice(
            id: "slow",
            coordinates: [
                CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
                CLLocationCoordinate2D(latitude: 50.453, longitude: 30.52)
            ],
            speedKmh: 8
        )
        let fast = SpeedColoredSlice(
            id: "fast",
            coordinates: [
                CLLocationCoordinate2D(latitude: 50.453, longitude: 30.52),
                CLLocationCoordinate2D(latitude: 50.4535, longitude: 30.52)
            ],
            speedKmh: 40
        )
        let shares = Dictionary(uniqueKeysWithValues: RidePaceShare.fractions(slices: [slow, fast], scale: .default))
        XCTAssertGreaterThan(shares[.slow] ?? 0, shares[.fast] ?? 0)
        XCTAssertEqual((shares[.slow] ?? 0) + (shares[.medium] ?? 0) + (shares[.fast] ?? 0), 1, accuracy: 0.001)
    }

    func testMapHeatmapUsesNewestUntilAnotherRideIsSelected() {
        let newest = UUID()
        let older = UUID()
        XCTAssertTrue(MapRideHeatmap.isActive(rideID: newest, newestRideID: newest, selectedRideID: nil))
        XCTAssertFalse(MapRideHeatmap.isActive(rideID: older, newestRideID: newest, selectedRideID: nil))
        XCTAssertTrue(MapRideHeatmap.isActive(rideID: older, newestRideID: newest, selectedRideID: older))
        XCTAssertFalse(MapRideHeatmap.isActive(rideID: newest, newestRideID: newest, selectedRideID: older))
    }

    @MainActor
    func testSelectingBikeDoesNotResetChainWear() throws {
        let schema = Schema([Ride.self, Bike.self, DayJournal.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let viewModel = RidesViewModel(modelContext: container.mainContext)

        viewModel.addBike(name: "Steel", odometerMeters: 12_000, chainIntervalMeters: 400_000)
        let bike = try XCTUnwrap(viewModel.bikes.first)
        bike.metersAtLastChainService = 2_000
        XCTAssertEqual(bike.metersSinceChainService, 10_000, accuracy: 0.5)

        UserDefaults.standard.set(bike.id.uuidString, forKey: PreferenceKey.selectedBikeId)
        XCTAssertEqual(bike.metersSinceChainService, 10_000, accuracy: 0.5)
        XCTAssertEqual(bike.metersAtLastChainService, 2_000, accuracy: 0.5)

        viewModel.resetChain(for: bike)
        XCTAssertEqual(bike.metersSinceChainService, 0, accuracy: 0.5)
    }
}
