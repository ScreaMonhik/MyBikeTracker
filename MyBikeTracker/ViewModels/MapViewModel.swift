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



/// ViewModel для управления состоянием карты и трекинга поездок.
/// Обеспечивает логику автоцентровки, построения маршрута, подсчёта скорости и времени, а также взаимодействие с сервисом локаций.
@MainActor
final class MapViewModel: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {

    // MARK: - Published свойства для реактивного UI

    /// Позиция камеры карты (автоматическая или установленная вручную)
    @Published var cameraPosition: MapCameraPosition = .automatic

    /// Точки текущего маршрута
    @Published var routeCoordinates: [CLLocationCoordinate2D] = []

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

    // MARK: - Navigation / Routing (Ephemeral)

    /// Ephemeral navigation destination
    @Published var navigationDestination: CLLocationCoordinate2D?

    /// Ephemeral navigation route
    @Published var navigationRoute: MKRoute?

    // MARK: - Address Search & Autocomplete

    /// Ephemeral search query for address autocomplete
    @Published var searchQuery: String = "" {
        didSet {
            searchCompleter.queryFragment = searchQuery
        }
    }

    /// Search completer results
    @Published var searchResults: [MKLocalSearchCompletion] = []

    private let searchCompleter = MKLocalSearchCompleter()

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

    /// Сколько точек уже учтено в `traveledDistance`
    private var lastDistanceCount: Int = 0

    /// Последние значения, отправленные в Live Activity — чтобы не слать дубликаты
    private var lastLiveActivitySignature: (elapsed: Int, speed: Int, distance: Int, paused: Bool)?

    // MARK: - Инициализация

    /// Предотвращаем инициализацию без сервисов
    override init() {
        fatalError("Use init(locationService:ridesViewModel:) instead")
    }

    /// Основной инициализатор с передачей зависимостей
    init(locationService: LocationService, ridesViewModel: RidesViewModel, healthKitService: HealthKitService? = nil, liveActivityService: LiveActivityService? = nil) {
        self.locationService = locationService
        self.ridesViewModel = ridesViewModel
        self.healthKitService = healthKitService
        self.liveActivityService = liveActivityService

        super.init()

        // Устанавливаем регион по умолчанию (например, Киев)
        let defaultLocation = CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        let defaultRegion = MKCoordinateRegion(center: defaultLocation,
                                               span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        self.currentRegion = defaultRegion
        self.cameraPosition = .region(defaultRegion)

        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]

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

        locationService.$recordedLocations
            .receive(on: DispatchQueue.main)
            .sink { [weak self] locations in
                self?.routeCoordinates = locations.map(\.coordinate)
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

        checkRerouting(currentLocation: location)
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

    // MARK: - Navigation / Routing Logic

    func calculateRoute(to destination: CLLocationCoordinate2D) async {
        guard let startLoc = locationService.currentLocation else { return }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: startLoc.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = .automobile

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            self.navigationDestination = destination
            self.navigationRoute = response.routes.first
        } catch {
            print("Route calculation failed: \(error)")
        }
    }

    func clearRoute() {
        navigationDestination = nil
        navigationRoute = nil
    }

    func updateCompleterRegion(_ region: MKCoordinateRegion) {
        searchCompleter.region = region
    }

    func selectCompletion(_ completion: MKLocalSearchCompletion) async {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let coordinate = response.mapItems.first?.placemark.coordinate {
                await calculateRoute(to: coordinate)
            }
        } catch {
            print("Local search failed for completion: \(error)")
        }
    }

    // MARK: - MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor [weak self] in
            self?.searchResults = results
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("MKLocalSearchCompleter error: \(error.localizedDescription)")
    }

    private func checkRerouting(currentLocation: CLLocation) {
        guard let route = navigationRoute, let destination = navigationDestination else { return }
        
        let distance = distanceToPolyline(coordinate: currentLocation.coordinate, polyline: route.polyline)
        if distance > 50.0 {
            Task {
                await calculateRoute(to: destination)
            }
        }
    }

    private func distanceToPolyline(coordinate: CLLocationCoordinate2D, polyline: MKPolyline) -> CLLocationDistance {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var minDistance: CLLocationDistance = .greatestFiniteMagnitude

        let pointCount = polyline.pointCount
        guard pointCount > 0 else { return minDistance }

        let points = polyline.points()
        let step = max(1, pointCount / 80)
        var index = 0
        while index < pointCount {
            let ptCoordinate = points[index].coordinate
            let distance = location.distance(from: CLLocation(latitude: ptCoordinate.latitude, longitude: ptCoordinate.longitude))
            if distance < minDistance {
                minDistance = distance
            }
            index += step
        }
        return minDistance
    }

    // MARK: - Управление трекингом

    /// Запускает трекинг: инициализация времени, сброс пауз и запуск сервисов
    func startTracking() {
        isTrackingActive = true

        startTime = Date()
        totalPausedTime = 0
        pauseStartTime = nil
        lowSpeedStartTime = nil
        lastDistanceCount = 0
        lastLiveActivitySignature = nil
        isPaused = false
        isAutoPaused = false
        shouldAutoCenter = true
        maxSpeed = 0
        traveledDistance = 0

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
        locationService.resumeTracking()
        startMetrics()
        Task { await liveActivityService?.update(elapsed: elapsedTime, speed: currentSpeed, distance: traveledDistance, isPaused: false) }
    }

    // MARK: - Подсчёт скорости и времени

    private func startMetrics() {
        stopMetrics()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMetrics()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
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

        calculateTraveledDistance()

        let elapsedHours = elapsedTime / 3600
        if elapsedHours > 0 {
            averageSpeed = (traveledDistance / 1000) / elapsedHours
        } else {
            averageSpeed = 0
        }

        pushLiveActivityIfNeeded()
    }

    private func pushLiveActivityIfNeeded() {
        let signature = (
            elapsed: Int(elapsedTime),
            speed: Int(currentSpeed * 10),
            distance: Int(traveledDistance),
            paused: isPaused
        )
        guard lastLiveActivitySignature == nil || lastLiveActivitySignature! != signature else { return }
        lastLiveActivitySignature = signature

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
            lastDistanceCount = locations.count
            return
        }

        if locations.count < lastDistanceCount {
            lastDistanceCount = 0
            traveledDistance = 0
        }

        let startIndex = max(lastDistanceCount, 1)
        if startIndex < locations.count {
            var added: Double = 0
            for index in startIndex..<locations.count {
                added += locations[index].distance(from: locations[index - 1])
            }
            traveledDistance += added
            lastDistanceCount = locations.count
        }
    }

    // MARK: - Сохранение поездки

    private func saveCurrentRide() {
        guard let start = startTime else { return }

        let ride = Ride(
            route: routeCoordinates,
            startDate: start,
            endDate: Date(),
            distance: traveledDistance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            duration: elapsedTime,
            matchedRoute: matchedRoute.isEmpty ? nil : matchedRoute
        )

        ridesViewModel?.addRide(ride)

        if healthKitEnabled, let hk = healthKitService {
            let locations = locationService.recordedLocations
            Task {
                try? await hk.saveWorkout(ride: ride, locations: locations)
            }
        }

        routeCoordinates.removeAll()
        matchedRoute.removeAll()
        elapsedTime = 0
        traveledDistance = 0
        currentSpeed = 0
        averageSpeed = 0
        maxSpeed = 0
        startTime = nil
        lastDistanceCount = 0
        lastLiveActivitySignature = nil
    }

}
