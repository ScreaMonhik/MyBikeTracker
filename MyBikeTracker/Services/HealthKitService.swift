//
//  HealthKitService.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 06.03.2025.
//

import Foundation
import HealthKit
import CoreLocation

/// Wraps all HealthKit write operations for cycling workouts.
final class HealthKitService {

    private let store = HKHealthStore()
    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    // MARK: - Authorization

    /// Requests HealthKit write permissions. Safe to call multiple times – HealthKit caches the user's decision.
    func requestAuthorization() async {
        guard isAvailable else { return }

        let typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute()
        ]

        try? await store.requestAuthorization(toShare: typesToShare, read: [])
    }

    // MARK: - Save Workout

    /// Saves a completed cycling workout to HealthKit, including GPS route.
    /// - Parameters:
    ///   - ride: The finished `Ride` model.
    ///   - locations: Raw `CLLocation` array recorded during the ride (for the route).
    func saveWorkout(ride: Ride, locations: [CLLocation]) async throws {
        guard isAvailable else { return }

        // 1. Build the HKWorkout
        let distanceQuantity = HKQuantity(unit: .meter(), doubleValue: ride.distance)
        let energyQuantity = estimatedCalories(distanceMeters: ride.distance)

        let workout = HKWorkout(
            activityType: .cycling,
            start: ride.startDate,
            end: ride.endDate,
            duration: ride.duration,
            totalEnergyBurned: energyQuantity,
            totalDistance: distanceQuantity,
            metadata: nil
        )

        // 2. Save the workout object
        try await store.save(workout)

        // 3. Build and attach a GPS route (only if we have location data)
        guard !locations.isEmpty else { return }
        try await attachRoute(to: workout, locations: locations)
    }

    // MARK: - Private helpers

    /// Attach an `HKWorkoutRoute` to a saved workout using a `HKWorkoutRouteBuilder`.
    private func attachRoute(to workout: HKWorkout, locations: [CLLocation]) async throws {
        let builder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        try await builder.insertRouteData(locations)
        try await builder.finishRoute(with: workout, metadata: nil)
    }

    /// Rough calorie estimate: ~25 kcal per km for cycling (no HRM).
    private func estimatedCalories(distanceMeters: Double) -> HKQuantity {
        let kcal = (distanceMeters / 1000.0) * 25.0
        return HKQuantity(unit: .kilocalorie(), doubleValue: max(kcal, 0))
    }
}
