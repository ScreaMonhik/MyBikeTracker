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

    /// Live track split at GPS / network gaps, plus road fills when they recover.
    @Published var routeSegments: [[CLLocationCoordinate2D]] = []

    /// Live track colored by speed on each stretch.
    @Published var liveSpeedSlices: [SpeedColoredSlice] = []

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

    /// Набор высоты за текущую поездку, метры
    @Published var elevationGain: Double = 0

    /// Скорректированный маршрут после «мачинга» с помощью Mapbox
    @Published var matchedRoute: [CLLocationCoordinate2D] = []

    /// Флаг автоцентровки карты на текущей позиции пользователя
    @Published var shouldAutoCenter = true

    /// Трекинг активен/неактивен
    @Published var isTrackingActive: Bool = false

    /// Полноэкранное подтверждение завершения поездки
    @Published var isEndRideConfirmationPresented = false

    var isRideInProgress: Bool {
        isTrackingActive || startTime != nil
    }

    /// Флаг программного изменения региона карты (чтобы отличать от ручных изменений пользователя)
    @Published var isProgrammaticRegionChange = false

    /// Текущий регион карты (используется для контроля позиции камеры)
    @Published var currentRegion: MKCoordinateRegion?

    /// App GPS / simulation fix used for the rider puck (not MapKit's system user location).
    @Published private(set) var displayCoordinate: CLLocationCoordinate2D?
    @Published private(set) var displayCourse: CLLocationDirection = -1

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
    @AppStorage(PreferenceKey.healthKitEnabled) private var healthKitEnabled: Bool = true

    @AppStorage(PreferenceKey.autoPauseSpeedKmh) private var autoPauseSpeedKmh: Double = 1.0
    @AppStorage(PreferenceKey.autoPauseDelaySeconds) private var autoPauseDelaySeconds: Double = 5.0
    @AppStorage(PreferenceKey.selectedBikeId) var selectedBikeId: String = ""

    let sensorService = BluetoothSensorService()
    let sessionBridge = RideSessionBridge()
    private let mapboxService = MapboxRouteService()

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

    private var gapFills: [String: [CLLocationCoordinate2D]] = [:]
    private var fillingGapKeys = Set<String>()

    #if DEBUG
    @Published var isDeveloperSimulationActive = false
    private var currentRideIsSimulated = false
    #endif

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

        sessionBridge.mapViewModel = self
        sessionBridge.activate()
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
                self?.updateLiveTrack(from: locations)
            }
            .store(in: &cancellables)
    }

    private func updateLiveTrack(from locations: [CLLocation]) {
        routeCoordinates = locations.map(\.coordinate)
        let gpsSegments = RideTrackGeometry.segments(from: locations)
        requestGapFills(for: gpsSegments)
        routeSegments = RideTrackGeometry.stitchedDisplay(gpsSegments: gpsSegments, fills: gapFills)
        liveSpeedSlices = RideTrackGeometry.speedColoredSlices(gpsSegments: gpsSegments, fills: gapFills)
    }

    private func requestGapFills(for segments: [[CLLocation]]) {
        guard segments.count >= 2 else { return }
        for index in 1..<segments.count {
            guard let start = segments[index - 1].last, let end = segments[index].first else { continue }
            let key = RideTrackGeometry.gapKey(from: start, to: end)
            guard gapFills[key] == nil, !fillingGapKeys.contains(key) else { continue }
            let jump = end.distance(from: start)
            guard jump <= RideTrackGeometry.maxFillDistance else { continue }

            fillingGapKeys.insert(key)
            Task { [weak self] in
                let path = await RoadPathService.routeOnRoads(from: start.coordinate, to: end.coordinate)
                guard let self else { return }
                self.fillingGapKeys.remove(key)
                guard path.count >= 2 else { return }
                self.gapFills[key] = path
                let latest = self.locationService.recordedLocations
                let gpsSegments = RideTrackGeometry.segments(from: latest)
                self.routeSegments = RideTrackGeometry.stitchedDisplay(
                    gpsSegments: gpsSegments,
                    fills: self.gapFills
                )
                self.liveSpeedSlices = RideTrackGeometry.speedColoredSlices(
                    gpsSegments: gpsSegments,
                    fills: self.gapFills
                )
                self.calculateTraveledDistance()
            }
        }
    }

    /// Обработка обновления текущей локации
    private func handleLocationUpdate(_ location: CLLocation) {
        displayCoordinate = location.coordinate
        displayCourse = location.course

        // Авто-возобновление (если находимся в авто-паузе и начали двигаться)
        if isTrackingActive && isPaused && isAutoPaused {
            let speedKmh = max(0, location.speed) * 3.6
            if speedKmh >= autoPauseSpeedKmh {
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
        guard !isRideInProgress else { return }
        #if DEBUG
        if !isDeveloperSimulationActive {
            currentRideIsSimulated = false
        }
        #endif
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
        elevationGain = 0

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

        liveActivityService?.start(startDate: startTime ?? Date())
        pushWatchState()
    }

    func requestStopTracking() {
        guard isRideInProgress else { return }
        isEndRideConfirmationPresented = true
    }

    func confirmStopTracking() {
        isEndRideConfirmationPresented = false
        stopTracking()
    }

    func cancelStopTracking() {
        isEndRideConfirmationPresented = false
    }

    /// Останавливает трекинг и сохраняет поездку
    func stopTracking() {
        isTrackingActive = false
        isEndRideConfirmationPresented = false

        #if DEBUG
        locationService.stopRideSimulation()
        isDeveloperSimulationActive = false
        #endif

        locationService.stopTracking()
        stopMetrics()

        let locations = locationService.recordedLocations
        let start = startTime
        let end = Date()
        let duration = elapsedTime
        let distance = traveledDistance
        let avg = averageSpeed
        let maxSp = maxSpeed
        let elevation = ElevationCalculator.gain(from: locations)
        let bikeUUID = UUID(uuidString: selectedBikeId)
        let recoveredFills = gapFills

        let finalElapsed = elapsedTime
        let finalSpeed = currentSpeed
        let finalDistance = traveledDistance
        Task { await liveActivityService?.stop(elapsed: finalElapsed, speed: finalSpeed, distance: finalDistance) }

        resetLiveRideState()
        pushWatchState()

        // Save GPS immediately so a missing Mapbox token cannot drop the ride.
        let ride = persistRide(
            locations: locations,
            start: start,
            end: end,
            duration: duration,
            distance: distance,
            averageSpeed: avg,
            maxSpeed: maxSp,
            elevationGain: elevation,
            bikeId: bikeUUID,
            matched: []
        )

        Task {
            let matched = await Self.assembleMatchedRoute(
                locations: locations,
                mapboxService: mapboxService,
                knownFills: recoveredFills
            )
            await MainActor.run {
                if let ride, !matched.isEmpty {
                    ridesViewModel?.applyMatchedRoute(ride, coordinates: matched)
                }
            }
        }
    }

    /// Пауза трекинга
    func pauseTracking(auto: Bool = false) {
        guard !isPaused else { return }
        isPaused = true
        isAutoPaused = auto
        pauseStartTime = Date()
        locationService.pauseTracking()
        #if DEBUG
        locationService.pauseRideSimulationClock()
        #endif
        stopMetrics()
        Task { await liveActivityService?.update(elapsed: elapsedTime, speed: 0, distance: traveledDistance, isPaused: true) }
        pushWatchState()
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
        #if DEBUG
        locationService.resumeRideSimulationClock()
        #endif
        startMetrics()
        Task { await liveActivityService?.update(elapsed: elapsedTime, speed: currentSpeed, distance: traveledDistance, isPaused: false) }
        pushWatchState()
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
        #if DEBUG
        let skipAutoPause = locationService.isSimulatingRide
        #else
        let skipAutoPause = false
        #endif
        if isTrackingActive && !isPaused && !skipAutoPause {
            if currentSpeed < autoPauseSpeedKmh {
                if lowSpeedStartTime == nil {
                    lowSpeedStartTime = now
                } else if let lowSpeedTime = lowSpeedStartTime,
                          now.timeIntervalSince(lowSpeedTime) >= autoPauseDelaySeconds {
                    pauseTracking(auto: true)
                    lowSpeedStartTime = nil
                }
            } else {
                lowSpeedStartTime = nil
            }
        }

        calculateTraveledDistance()
        elevationGain = ElevationCalculator.gain(from: locationService.recordedLocations)

        let elapsedHours = elapsedTime / 3600
        if elapsedHours > 0 {
            averageSpeed = (traveledDistance / 1000) / elapsedHours
        } else {
            averageSpeed = 0
        }

        pushLiveActivityIfNeeded()
        pushWatchState()
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

        let gpsSegments = RideTrackGeometry.segments(from: locations)
        var distance = gpsSegments.reduce(0.0) { $0 + RideTrackGeometry.polylineDistance($1) }
        for index in 1..<gpsSegments.count {
            guard let start = gpsSegments[index - 1].last, let end = gpsSegments[index].first else { continue }
            let key = RideTrackGeometry.gapKey(from: start, to: end)
            guard let fill = gapFills[key] else { continue }
            let road = RideTrackGeometry.polylineDistance(fill)
            let duration = end.timestamp.timeIntervalSince(start.timestamp)
            if RideTrackGeometry.isPlausibleFill(distance: road, duration: duration) {
                distance += road
            }
        }
        traveledDistance = distance
        lastDistanceCount = locations.count
    }

    private static func assembleMatchedRoute(
        locations: [CLLocation],
        mapboxService: MapboxRouteService,
        knownFills: [String: [CLLocationCoordinate2D]]
    ) async -> [CLLocationCoordinate2D] {
        let gpsSegments = RideTrackGeometry.segments(from: locations)
        guard !gpsSegments.isEmpty else { return [] }

        var pieces: [[CLLocationCoordinate2D]] = []
        let useMapbox = mapboxService.isConfigured
        for segment in gpsSegments {
            let matched = useMapbox ? await mapboxService.matchRoute(locations: segment) : []
            if matched.count >= 2 {
                pieces.append(matched)
            } else {
                pieces.append(segment.map(\.coordinate))
            }
        }

        var assembled: [CLLocationCoordinate2D] = []
        for index in 0..<pieces.count {
            let piece = pieces[index]
            guard piece.count >= 2 else { continue }
            if assembled.isEmpty {
                assembled.append(contentsOf: piece)
                continue
            }
            if let last = assembled.last {
                let jump = CLLocation(latitude: last.latitude, longitude: last.longitude)
                    .distance(from: CLLocation(latitude: piece[0].latitude, longitude: piece[0].longitude))
                if jump > 40 {
                    var fill = [CLLocationCoordinate2D]()
                    if let start = gpsSegments[index - 1].last, let end = gpsSegments[index].first {
                        fill = knownFills[RideTrackGeometry.gapKey(from: start, to: end)] ?? []
                    }
                    if fill.count < 2 {
                        fill = await RoadPathService.routeOnRoads(from: last, to: piece[0])
                    }
                    if fill.count >= 2 {
                        assembled.append(contentsOf: fill.dropFirst())
                    }
                }
            }
            assembled.append(contentsOf: piece.dropFirst())
        }
        return assembled
    }

    // MARK: - Сохранение поездки

    @discardableResult
    private func persistRide(
        locations: [CLLocation],
        start: Date?,
        end: Date,
        duration: TimeInterval,
        distance: Double,
        averageSpeed: Double,
        maxSpeed: Double,
        elevationGain: Double,
        bikeId: UUID?,
        matched: [CLLocationCoordinate2D]
    ) -> Ride? {
        guard let start else { return nil }

        let ride = Ride(
            locations: locations,
            startDate: start,
            endDate: end,
            distance: distance,
            averageSpeed: averageSpeed,
            maxSpeed: maxSpeed,
            duration: duration,
            matchedRoute: matched.isEmpty ? nil : matched,
            elevationGain: elevationGain,
            bikeId: bikeId
        )

        ridesViewModel?.addRide(ride)

        #if DEBUG
        let skipHealthKit = currentRideIsSimulated
        currentRideIsSimulated = false
        #else
        let skipHealthKit = false
        #endif

        if healthKitEnabled, !skipHealthKit, let hk = healthKitService {
            Task {
                try? await hk.saveWorkout(ride: ride, locations: locations)
            }
        }

        return ride
    }

    private func resetLiveRideState() {
        routeCoordinates.removeAll()
        routeSegments.removeAll()
        liveSpeedSlices.removeAll()
        gapFills.removeAll()
        fillingGapKeys.removeAll()
        matchedRoute.removeAll()
        elapsedTime = 0
        traveledDistance = 0
        elevationGain = 0
        currentSpeed = 0
        averageSpeed = 0
        maxSpeed = 0
        startTime = nil
        lastDistanceCount = 0
        lastLiveActivitySignature = nil
    }

    func makeLocationSharePayload() -> LocationSharePayload? {
        guard let location = locationService.currentLocation else { return nil }
        let coordinate = location.coordinate
        let urlString = String(
            format: "https://maps.apple.com/?ll=%.6f,%.6f&q=Ride",
            coordinate.latitude,
            coordinate.longitude
        )
        guard let url = URL(string: urlString) else { return nil }
        let text = String(
            format: NSLocalizedString("share_location_message", comment: ""),
            RideFormatters.distance(meters: traveledDistance),
            RideFormatters.speed(kmh: currentSpeed),
            url.absoluteString
        )
        return LocationSharePayload(text: text, url: url)
    }

    private func pushWatchState() {
        sessionBridge.pushState(
            tracking: isRideInProgress,
            paused: isPaused,
            elapsed: elapsedTime,
            speed: currentSpeed,
            distance: traveledDistance
        )
    }

    #if DEBUG
    // MARK: - Developer ride simulation

    /// Starts a live ride that moves around the current (or Kyiv) point at a varying city pace.
    func startDeveloperSimulatedRide() {
        locationService.stopRideSimulation()
        locationService.armRideSimulation()
        currentRideIsSimulated = true
        isDeveloperSimulationActive = true
        startTracking()
        locationService.startRideSimulation(
            around: locationService.currentLocation?.coordinate,
            startMoving: true
        )
        forceAutoCenter()
    }

    /// Starts a short simulated track and immediately pauses it.
    func startDeveloperPausedRide() {
        locationService.stopRideSimulation()
        locationService.armRideSimulation()
        currentRideIsSimulated = true
        isDeveloperSimulationActive = true
        startTracking()
        locationService.startRideSimulation(
            around: locationService.currentLocation?.coordinate,
            startMoving: false
        )
        pauseTracking()
        forceAutoCenter()
    }

    func stopDeveloperSimulationKeepingRide() {
        locationService.stopRideSimulation()
        isDeveloperSimulationActive = false
    }

    /// Adds a few dated rides so History and Calendar have something to show.
    func seedDeveloperSampleRides() {
        let calendar = Calendar.current
        let origin = locationService.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 50.4501, longitude: 30.5234)
        let samples: [(daysAgo: Int, hour: Int, meters: Double, minutes: Double, climb: Double)] = [
            (0, 9, 8_400, 32, 86),
            (1, 18, 12_200, 48, 142),
            (3, 8, 21_500, 75, 310),
            (9, 11, 6_300, 24, 54)
        ]

        for sample in samples {
            guard let day = calendar.date(byAdding: .day, value: -sample.daysAgo, to: Date()) else { continue }
            var startParts = calendar.dateComponents([.year, .month, .day], from: day)
            startParts.hour = sample.hour
            startParts.minute = 15
            guard let start = calendar.date(from: startParts) else { continue }
            let end = start.addingTimeInterval(sample.minutes * 60)
            let route = Self.sampleRoute(from: origin, meters: sample.meters)
            let hours = sample.minutes / 60
            let altitudes = route.enumerated().map { index, _ -> Double? in
                168 + 18 * sin(Double(index) * 0.07)
            }
            let ride = Ride(
                route: route,
                startDate: start,
                endDate: end,
                distance: sample.meters,
                averageSpeed: hours > 0 ? (sample.meters / 1000) / hours : 0,
                maxSpeed: 28,
                duration: sample.minutes * 60,
                elevationGain: sample.climb,
                altitudes: altitudes
            )
            ridesViewModel?.addRide(ride)
        }
    }

    private static func sampleRoute(from origin: CLLocationCoordinate2D, meters: Double) -> [CLLocationCoordinate2D] {
        let loop = LocationService.makeParkLoop(around: origin, stepMeters: 8)
        guard !loop.isEmpty else { return [] }
        var travelled = 0.0
        var result: [CLLocationCoordinate2D] = [loop[0]]
        var index = 1
        while travelled < meters {
            let prev = result[result.count - 1]
            let next = loop[index % loop.count]
            travelled += CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                .distance(from: CLLocation(latitude: next.latitude, longitude: next.longitude))
            result.append(next)
            index += 1
            if index > loop.count * 8 { break }
        }
        return result
    }
    #endif
}
