import Foundation
import HealthKit
import CoreLocation

final class HealthKitService {
    private let store = HKHealthStore()
    private var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async {
        guard isAvailable else { return }

        var typesToShare: Set<HKSampleType> = [
            HKQuantityType.workoutType(),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.activeEnergyBurned),
            HKSeriesType.workoutRoute()
        ]
        if let heartRate = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            typesToShare.insert(heartRate)
        }

        try? await store.requestAuthorization(toShare: typesToShare, read: [])
    }

    func saveWorkout(ride: Ride, locations: [CLLocation]) async throws {
        guard isAvailable else { return }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .cycling
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: ride.startDate)

        var samples: [HKSample] = []
        let distanceType = HKQuantityType(.distanceCycling)
        let energyType = HKQuantityType(.activeEnergyBurned)
        samples.append(
            HKQuantitySample(
                type: distanceType,
                quantity: HKQuantity(unit: .meter(), doubleValue: ride.distance),
                start: ride.startDate,
                end: ride.endDate
            )
        )

        let kilocalories = Self.estimatedKilocalories(
            distanceMeters: ride.distance,
            duration: ride.duration,
            averageHeartRate: ride.averageHeartRate
        )
        samples.append(
            HKQuantitySample(
                type: energyType,
                quantity: HKQuantity(unit: .kilocalorie(), doubleValue: kilocalories),
                start: ride.startDate,
                end: ride.endDate
            )
        )

        if ride.averageHeartRate > 0, let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
            samples.append(
                HKQuantitySample(
                    type: heartRateType,
                    quantity: HKQuantity(
                        unit: HKUnit.count().unitDivided(by: .minute()),
                        doubleValue: ride.averageHeartRate
                    ),
                    start: ride.startDate,
                    end: ride.endDate
                )
            )
        }

        try await builder.addSamples(samples)
        if ride.elevationGain > 0 {
            try await builder.addMetadata([
                HKMetadataKeyElevationAscended: HKQuantity(unit: .meter(), doubleValue: ride.elevationGain)
            ])
        }
        try await builder.endCollection(at: ride.endDate)
        guard let workout = try await builder.finishWorkout() else { return }

        guard !locations.isEmpty else { return }
        try await attachRoute(to: workout, locations: locations)
    }

    private func attachRoute(to workout: HKWorkout, locations: [CLLocation]) async throws {
        let builder = HKWorkoutRouteBuilder(healthStore: store, device: nil)
        try await builder.insertRouteData(locations)
        try await builder.finishRoute(with: workout, metadata: nil)
    }

    static func estimatedKilocalories(
        distanceMeters: Double,
        duration: TimeInterval,
        averageHeartRate: Double,
        weightKilograms: Double = 70
    ) -> Double {
        let hours = max(duration / 3600, 1.0 / 60)
        let kilometers = max(distanceMeters / 1000, 0)
        let speedKmh = hours > 0 ? kilometers / hours : 0
        let met = min(12, max(3.5, 3.5 + speedKmh / 5))
        let fromMET = met * 3.5 * weightKilograms * (duration / 60) / 200
        if averageHeartRate >= 90 {
            let kcalPerMinute = max(
                0,
                (-55.0969 + 0.6309 * averageHeartRate + 0.1988 * weightKilograms + 0.2017 * 35) / 4.184
            )
            let fromHeartRate = kcalPerMinute * (duration / 60)
            return max(fromMET, fromHeartRate)
        }
        return max(fromMET, 0)
    }
}
