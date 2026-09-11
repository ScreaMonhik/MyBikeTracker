//
//  LocationService.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import Foundation
import CoreLocation
import Combine

final class LocationService: NSObject, ObservableObject {
    private let locationManager = CLLocationManager()

    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var recordedLocations: [CLLocation] = []
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// Флаг активной записи маршрута (отдельно от получения текущей позиции)
    private var isRecording: Bool = false

    /// Минимальное расстояние (в метрах) между точками для записи
    private let minimumDistanceFilter: Double = 5.0

    /// Максимально допустимая погрешность GPS (в метрах)
    private let maximumHorizontalAccuracy: Double = 30.0

    override init() {
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.activityType = .fitness
        locationManager.distanceFilter = minimumDistanceFilter

        locationManager.requestAlwaysAuthorization()
        // Сразу начинаем получать позицию для отображения на карте
        locationManager.startUpdatingLocation()
    }

    // MARK: - Tracking (запись маршрута)

    func startTracking() {
        recordedLocations = []
        isRecording = true
    }

    func stopTracking() {
        isRecording = false
    }

    func pauseTracking() {
        isRecording = false
    }

    func resumeTracking() {
        isRecording = true
    }

    #if DEBUG
    @Published private(set) var isSimulatingRide = false

    private var simulationTimer: Timer?
    private var simulationPath: [CLLocationCoordinate2D] = []
    private var simulationIndex = 0
    private var simulationGeneration = 0
    /// One point per second; spacing on the path matches this so distance ≈ speed × time.
    private let simulatedSpeedMps: Double = 5.5
    private let simulatedTick: TimeInterval = 1

    /// Blocks real GPS callbacks before tracking starts, so a simulator jump cannot leak in.
    func armRideSimulation() {
        isSimulatingRide = true
    }

    /// Starts a fresh simulated GPS feed along real roads and sidewalks.
    func startRideSimulation(around origin: CLLocationCoordinate2D?, startMoving: Bool = true) {
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulationGeneration += 1
        let generation = simulationGeneration
        isSimulatingRide = true
        recordedLocations = []
        isRecording = true
        simulationPath = []
        simulationIndex = 0

        let center = origin
            ?? currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        let shouldStartClock = startMoving

        Task { [weak self] in
            let roadPath = await DeveloperRoadPath.makeLoop(
                around: center,
                stepMeters: self?.simulatedSpeedMps ?? 5.5
            )
            await MainActor.run {
                guard let self, self.simulationGeneration == generation, self.isSimulatingRide else { return }
                self.simulationPath = roadPath
                guard !self.simulationPath.isEmpty else { return }
                self.emitSimulationTick()
                self.emitSimulationTick()
                if shouldStartClock {
                    self.resumeRideSimulationClock()
                }
            }
        }
    }

    func stopRideSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        simulationGeneration += 1
        isSimulatingRide = false
        simulationPath = []
        simulationIndex = 0
    }

    func pauseRideSimulationClock() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }

    func resumeRideSimulationClock() {
        guard isSimulatingRide else { return }
        simulationTimer?.invalidate()
        let interval = simulatedTick
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async {
                self?.emitSimulationTick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        simulationTimer = timer
    }

    private func emitSimulationTick() {
        guard !simulationPath.isEmpty else { return }
        let current = simulationPath[simulationIndex % simulationPath.count]
        let next = simulationPath[(simulationIndex + 1) % simulationPath.count]
        let from = CLLocation(latitude: current.latitude, longitude: current.longitude)
        let to = CLLocation(latitude: next.latitude, longitude: next.longitude)
        let course = from.course(to: to)
        let altitude = 168 + 8 * sin(Double(simulationIndex) * 0.09)

        let location = CLLocation(
            coordinate: current,
            altitude: altitude,
            horizontalAccuracy: 4,
            verticalAccuracy: 3,
            course: course,
            speed: simulatedSpeedMps,
            timestamp: Date()
        )
        acceptSimulatedLocation(location)
        simulationIndex += 1
    }

    /// Simulated points always record; the 5 m GPS filter is not applied.
    private func acceptSimulatedLocation(_ location: CLLocation) {
        currentLocation = location
        recordedLocations.append(location)
    }

    /// Smooth closed park oval, resampled so every chord is ~`stepMeters`.
    static func makeParkLoop(
        around center: CLLocationCoordinate2D,
        stepMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let step = max(stepMeters, 2)
        let eastRadius = 150.0
        let northRadius = 95.0
        let sampleCount = 720
        var raw: [(east: Double, north: Double)] = []
        raw.reserveCapacity(sampleCount)
        for index in 0..<sampleCount {
            let t = Double(index) / Double(sampleCount) * 2 * .pi
            raw.append((eastRadius * cos(t), northRadius * sin(t)))
        }

        var offsets: [(east: Double, north: Double)] = [raw[0]]
        var leftover = 0.0
        for index in 1...sampleCount {
            let previous = raw[index - 1]
            let next = raw[index % sampleCount]
            let dx = next.east - previous.east
            let dy = next.north - previous.north
            let segment = hypot(dx, dy)
            guard segment > 0 else { continue }

            var consumed = 0.0
            while leftover + (segment - consumed) >= step {
                let need = step - leftover
                consumed += need
                let fraction = consumed / segment
                offsets.append((previous.east + dx * fraction, previous.north + dy * fraction))
                leftover = 0
            }
            leftover += segment - consumed
        }

        if offsets.count > 2 {
            let first = offsets[0]
            let last = offsets[offsets.count - 1]
            if hypot(last.east - first.east, last.north - first.north) < step * 0.6 {
                offsets.removeLast()
            }
        }

        return offsets.map { offsetEastNorth(from: center, east: $0.east, north: $0.north) }
    }

    static func offsetEastNorth(
        from origin: CLLocationCoordinate2D,
        east: Double,
        north: Double
    ) -> CLLocationCoordinate2D {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = 111_320.0 * cos(origin.latitude * .pi / 180)
        return CLLocationCoordinate2D(
            latitude: origin.latitude + north / metersPerDegreeLat,
            longitude: origin.longitude + east / max(metersPerDegreeLon, 1)
        )
    }

    static func developerOffset(
        _ origin: CLLocationCoordinate2D,
        meters: Double,
        bearingDegrees: Double
    ) -> CLLocationCoordinate2D {
        let bearing = bearingDegrees * .pi / 180
        return offsetEastNorth(
            from: origin,
            east: meters * sin(bearing),
            north: meters * cos(bearing)
        )
    }
    #endif
}

#if DEBUG
private extension CLLocation {
    func course(to other: CLLocation) -> CLLocationDirection {
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let lat2 = other.coordinate.latitude * .pi / 180
        let lon2 = other.coordinate.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}
#endif

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        // Фильтрация GPS-шума по точности
        guard newLocation.horizontalAccuracy >= 0,
              newLocation.horizontalAccuracy <= maximumHorizontalAccuracy else { return }

        DispatchQueue.main.async {
            #if DEBUG
            if self.isSimulatingRide { return }
            #endif
            self.acceptLocation(newLocation)
        }
    }

    private func acceptLocation(_ newLocation: CLLocation) {
        currentLocation = newLocation

        if isRecording {
            if let last = recordedLocations.last,
               newLocation.distance(from: last) < minimumDistanceFilter { return }
            recordedLocations.append(newLocation)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            // Если разрешение получено — стартуем обновление позиции
            if manager.authorizationStatus == .authorizedAlways ||
               manager.authorizationStatus == .authorizedWhenInUse {
                manager.startUpdatingLocation()
            }
        }
    }
}
