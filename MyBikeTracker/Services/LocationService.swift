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
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let newLocation = locations.last else { return }

        // Фильтрация GPS-шума по точности
        guard newLocation.horizontalAccuracy >= 0,
              newLocation.horizontalAccuracy <= maximumHorizontalAccuracy else { return }

        DispatchQueue.main.async {
            self.currentLocation = newLocation

            // Записываем точки маршрута только если трекинг активен
            if self.isRecording {
                if let last = self.recordedLocations.last,
                   newLocation.distance(from: last) < self.minimumDistanceFilter { return }
                self.recordedLocations.append(newLocation)
            }
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
