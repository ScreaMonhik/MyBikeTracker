//
//  MapViewModel.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import Foundation
import MapKit
import Combine
import SwiftUI
import CoreLocation

enum MapCameraPosition {
    case automatic
    case region(MKCoordinateRegion)
}

/// ViewModel для управления состоянием карты и трекинга поездок.
/// Обеспечивает логику автоцентровки, построения маршрута, подсчёта скорости и времени, а также взаимодействие с сервисом локаций.
@MainActor
final class MapViewModel: ObservableObject {

    // MARK: - Published свойства для реактивного UI

    /// Позиция камеры карты (автоматическая или установленная вручную)
    @Published var cameraPosition: MapCameraPosition = .automatic

    /// Точки текущего маршрута
    @Published var route: [RoutePoint] = []

    /// Отладочный лог (для внутреннего использования)
    @Published var debugLog: String = ""

    /// Время начала трекинга
    @Published var startTime: Date?

    /// Прошедшее время в секундах с учётом пауз
    @Published var elapsedTime: TimeInterval = 0

    /// Текущая скорость (км/ч)
    @Published var currentSpeed: Double = 0

    /// Средняя скорость (км/ч)
    @Published var averageSpeed: Double = 0

    /// Максимальная скорость за поездку (км/ч)
    @Published var maxSpeed: Double = 0

    /// Флаг паузы трекинга
    @Published var isPaused: Bool = false

    /// Флаг авто-паузы
    @Published var isAutoPaused: Bool = false

    /// Пройденное расстояние в метрах
    @Published var traveledDistance: Double = 0

    /// Уникальные названия улиц, которые пользователь посетил
    @Published var visitedStreetNames: Set<String> = []

    /// Скорректированный маршрут после «мачинга» с помощью Mapbox
    @Published var matchedRoute: [CLLocationCoordinate2D] = []

    /// Флаг автоцентровки карты на текущей позиции пользователя
    @Published var shouldAutoCenter = true

    /// Трекинг активен/неактивен
    @Published var isTrackingActive: Bool = false

    /// Флаг программного изменения региона карты (чтобы отличать от ручных изменений пользователя)
    @Published var isProgrammaticRegionChange = false

    /// Текущий регион карты (используется для контроля позиции камеры)
    @Published var currentRegion: MKCoordinateRegion?

    // MARK: - Внешние зависимости

    /// Сервис локаций для получения данных GPS
    let locationService: LocationService

    /// ViewModel для управления сохранёнными поездками
    weak var ridesViewModel: RidesViewModel?

    /// Сервис для хранения Live Activity на экране блокировки
    var liveActivityService: LiveActivityService?

    /// Сервис для записи тренировок в Apple Health
    var healthKitService: HealthKitService?

    /// Включена ли синхронизация с Apple Health (из Settings)
    @AppStorage("healthkit_enabled") private var healthKitEnabled: Bool = true

    // MARK: - Внутренние переменные

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    /// Общее время паузы в секундах
    private var totalPausedTime: TimeInterval = 0

    /// Время начала паузы
    private var pauseStartTime: Date?

    /// Время, когда скорость впервые стала ниже порога авто-паузы
    private var lowSpeedStartTime: Date?

    /// Время последнего поиска улицы для оптимизации запросов
    private var lastStreetSearchTime: Date?

    // MARK: - Инициализация

    /// Предотвращаем инициализацию без сервисов
    init() {
        fatalError("Use init(locationService:ridesViewModel:) instead")
    }

    /// Основной инициализатор с передачей зависимостей
    init(locationService: LocationService, ridesViewModel: RidesViewModel, healthKitService: HealthKitService? = nil, liveActivityService: LiveActivityService? = nil) {
        self.locationService = locationService
        self.ridesViewModel = ridesViewModel
        self.healthKitService = healthKitService
        self.liveActivityService = liveActivityService

        // Устанавливаем регион по умолчанию (например, Киев)
        let defaultLocation = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        let defaultRegion = MKCoordinateRegion(center: defaultLocation,
                                               span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        self.currentRegion = defaultRegion
        self.cameraPosition = .region(defaultRegion)

        bindLocationUpdates()
    }

    // MARK: - Связывание с сервисом локаций

    /// Подписываемся на обновления текущей позиции и всех записанных точек маршрута
    private func bindLocationUpdates() {
        // Обновляем позицию камеры и регион карты при изменении текущей локации
        locationService.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                self?.handleLocationUpdate(location)
            }
            .store(in: &cancellables)

        // Обновляем маршрут для отображения на карте
        locationService.$recordedLocations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locations in
                self?.route = locations.map { RoutePoint(coordinate: $0.coordinate) }
            }
            .store(in: &cancellables)
    }

    /// Обработка обновления текущей локации
    private func handleLocationUpdate(_ location: CLLocation) {
        // Авто-возобновление (если находимся в авто-паузе и начали двигаться)
        if isTrackingActive && isPaused && isAutoPaused {
            let speedKmh = max(0, location.speed) * 3.6
            if speedKmh >= 1.0 {
                resumeTracking(auto: true)
            }
        }

        guard shouldAutoCenter else { return }

        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        // Центрируем карту только если расстояние сдвига больше 5 метров
        if let currentCenter = currentRegion?.center {
            let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                .distance(from: CLLocation(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))
            if distance > 5 {
                updateCameraRegion(to: region)
            }
        } else {
            updateCameraRegion(to: region)
        }

        // Периодически определяем название ближайшей улицы
        detectNearbyStreet(from: location)
    }

    /// Обновляет камеру карты программно
    private func updateCameraRegion(to region: MKCoordinateRegion) {
        isProgrammaticRegionChange = true
        cameraPosition = .region(region)
        currentRegion = region

        // Снимаем флаг программного изменения спустя короткую задержку
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.isProgrammaticRegionChange = false
        }
    }

    // MARK: - Автоцентрирование карты

    /// Принудительно включает автоцентрирование и обновляет позицию камеры
    func forceAutoCenter() {
        shouldAutoCenter = true
        if let location = locationService.currentLocation {
            let region = MKCoordinateRegion(center: location.coordinate,
                                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
            updateCameraRegion(to: region)
        }
    }

    /// Отключает автоцентрирование и обновляет регион карты при ручном перемещении
    func notifyManualRegionChange(to region: MKCoordinateRegion) {
        isProgrammaticRegionChange = false
        cameraPosition = .region(region)
        currentRegion = region
        shouldAutoCenter = false
    }

    // MARK: - Поиск ближайшей улицы

    /// Периодически (не чаще чем раз в 5 секунд) ищет ближайшую улицу и сохраняет её в набор посещённых
    private func detectNearbyStreet(from location: CLLocation) {
        let now = Date()
        if let lastTime = lastStreetSearchTime, now.timeIntervalSince(lastTime) < 5 {
            return
        }
        lastStreetSearchTime = now

        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self,
                  error == nil,
                  let street = placemarks?.first?.thoroughfare else { return }
            DispatchQueue.main.async {
                self.visitedStreetNames.insert(street)
            }
        }
    }

    // MARK: - Управление трекингом

    /// Запускает трекинг: инициализация времени, сброс пауз и запуск сервисов
    func startTracking() {
        isTrackingActive = true
        debugLog += "Start tracking...\n"

        startTime = Date()
        totalPausedTime = 0
        pauseStartTime = nil
        lowSpeedStartTime = nil
        isPaused = false
        isAutoPaused = false
        shouldAutoCenter = true
        maxSpeed = 0

        locationService.startTracking()
        startMetrics()

        // Центрируем карту сразу при старте
        if locationService.currentLocation != nil {
            forceAutoCenter()
        }

        // Запрашиваем права HealthKit при каждом старте (безопасно — система кешируем решение пользователя)
        if healthKitEnabled {
            Task { await healthKitService?.requestAuthorization() }
        }

        // Запускаем Live Activity
        liveActivityService?.start(startDate: startTime ?? Date())
    }

    /// Останавливает трекинг и сохраняет поездку
    func stopTracking() {
        isTrackingActive = false
        debugLog += "Stop tracking\n"

        locationService.stopTracking()
        stopMetrics()

        matchedRoute = locationService.recordedLocations.map { $0.coordinate }

        // Останавливаем Live Activity перед сохранением
        let finalElapsed = elapsedTime
        let finalSpeed = currentSpeed
        let finalDistance = traveledDistance
        Task { await liveActivityService?.stop(elapsed: finalElapsed, speed: finalSpeed, distance: finalDistance) }

        saveCurrentRide()
    }

    /// Пауза трекинга
    func pauseTracking(auto: Bool = false) {
        guard !isPaused else { return }
        isPaused = true
        isAutoPaused = auto
        pauseStartTime = Date()
        debugLog += auto ? "Auto-pause tracking\n" : "Pause tracking\n"
        locationService.pauseTracking()
        stopMetrics()
        Task { await liveActivityService?.update(elapsed: elapsedTime, speed: 0, distance: traveledDistance, isPaused: true) }
    }

    /// Возобновление трекинга
    func resumeTracking(auto: Bool = false) {
        guard isPaused else { return }
        if auto && !isAutoPaused { return }
        
        isPaused = false
        isAutoPaused = false
        lowSpeedStartTime = nil
        if let pauseStart = pauseStartTime {
            totalPausedTime += Date().timeIntervalSince(pauseStart)
        }
        pauseStartTime = nil
        debugLog += auto ? "Auto-resume tracking\n" : "Resume tracking\n"
        locationService.resumeTracking()
        startMetrics()
        Task { await liveActivityService?.update(elapsed: elapsedTime, speed: currentSpeed, distance: traveledDistance, isPaused: false) }
    }

    // MARK: - Подсчёт скорости и времени

    private func startMetrics() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }
    }

    private func stopMetrics() {
        timer?.invalidate()
        timer = nil
    }

    private func updateMetrics() {
        guard let start = startTime else { return }
        let now = Date()
        elapsedTime = now.timeIntervalSince(start) - totalPausedTime

        // Текущая скорость — последняя известная из сервиса локаций (если получена недавно)
        let lastLocation = locationService.currentLocation
        let timeSinceLastLocation = now.timeIntervalSince(lastLocation?.timestamp ?? now)
        
        if let speedMps = lastLocation?.speed, speedMps >= 0, timeSinceLastLocation < 5.0 {
            currentSpeed = speedMps * 3.6
            if currentSpeed > maxSpeed {
                maxSpeed = currentSpeed
            }
        } else {
            currentSpeed = 0
        }

        // Авто-пауза, если скорость меньше 1 км/ч дольше 5 секунд
        if isTrackingActive && !isPaused {
            if currentSpeed < 1.0 {
                if lowSpeedStartTime == nil {
                    lowSpeedStartTime = now
                } else if let lowSpeedTime = lowSpeedStartTime, now.timeIntervalSince(lowSpeedTime) >= 5.0 {
                    pauseTracking(auto: true)
                    lowSpeedStartTime = nil
                }
            } else {
                lowSpeedStartTime = nil
            }
        }

        // Средняя скорость — расстояние / время в часах
        let elapsedHours = elapsedTime / 3600
        if elapsedHours > 0 {
            averageSpeed = (traveledDistance / 1000) / elapsedHours
        } else {
            averageSpeed = 0
        }

        // Расчёт пройденного расстояния
        calculateTraveledDistance()

        // Обновляем Live Activity каждую секунду
        let elapsed = elapsedTime
        let speed = currentSpeed
        let distance = traveledDistance
        let paused = isPaused
        Task { await liveActivityService?.update(elapsed: elapsed, speed: speed, distance: distance, isPaused: paused) }
    }

    private func calculateTraveledDistance() {
        let locations = locationService.recordedLocations
        guard locations.count > 1 else {
            traveledDistance = 0
            return
        }

        var distance: Double = 0
        for i in 1..<locations.count {
            distance += locations[i].distance(from: locations[i - 1])
        }

        traveledDistance = distance
    }

    // MARK: - Сохранение поездки

    private func saveCurrentRide() {
        guard let start = startTime else { return }

        let ride = Ride(
            route: route.map { $0.coordinate },
            startDate: start,
            endDate: Date(),
            distance: traveledDistance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            duration: elapsedTime,
            matchedRoute: matchedRoute.isEmpty ? nil : matchedRoute
        )

        ridesViewModel?.addRide(ride)

        debugLog += "Saved ride: \(ride.startDate)\n"

        // Сохраняем тренировку в Apple Health (если включено в настройках)
        if healthKitEnabled, let hk = healthKitService {
            let locations = locationService.recordedLocations
            Task {
                do {
                    try await hk.saveWorkout(ride: ride, locations: locations)
                } catch {
                    debugLog += "HealthKit save error: \(error.localizedDescription)\n"
                }
            }
        }

        // Очистка для следующей поездки
        route.removeAll()
        matchedRoute.removeAll()
        visitedStreetNames.removeAll()
        elapsedTime = 0
        traveledDistance = 0
        currentSpeed = 0
        averageSpeed = 0
        maxSpeed = 0
        startTime = nil
    }

}
