//
//  TrackerView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI

struct TrackerView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var sensorService: BluetoothSensorService
    @State private var isShowingSearchSheet = false
    @State private var sharePayload: LocationSharePayload?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(viewModel: MapViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _sensorService = ObservedObject(wrappedValue: viewModel.sensorService)
    }

    @AppStorage(.trackerRouteColorKey) private var trackerColorHex: String = RouteLineColor.defaultTrackerHex
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(PreferenceKey.selectedBikeId) private var selectedBikeId = ""

    private var isRideActive: Bool {
        viewModel.startTime != nil
    }

    private var bikes: [Bike] {
        viewModel.ridesViewModel?.bikes ?? []
    }

    private var selectedBike: Bike? {
        bikes.first { $0.id.uuidString == selectedBikeId }
    }

    var body: some View {
        ZStack {
            mapSection

            VStack(spacing: 0) {
                if isRideActive {
                    rideInfoPlaque
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    if isRideActive, !viewModel.liveSpeedSlices.isEmpty {
                        SpeedTrackLegend()
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    Spacer()
                    mapTools
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if viewModel.restoredRideBanner {
                    Text(LocalizedStringKey("ride_restored_banner"))
                        .font(Brand.Font.caption)
                        .foregroundStyle(Brand.Color.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .liquidGlass(in: Capsule())
                        .padding(.bottom, 8)
                }

                if !viewModel.locationService.isAuthorized {
                    LocationPermissionView(locationService: viewModel.locationService)
                        .padding(.bottom, 10)
                }

                if !isRideActive, !bikes.isEmpty {
                    bikePicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                controlButtons
                    .padding(.bottom, 10)
            }
        }
        .animation(Brand.Motion.appear(reduceMotion: reduceMotion), value: isRideActive)
        .animation(Brand.Motion.snappy(reduceMotion: reduceMotion), value: viewModel.isPaused)
        .animation(Brand.Motion.snappy(reduceMotion: reduceMotion), value: viewModel.liveSpeedSlices.isEmpty)
        .sheet(isPresented: $isShowingSearchSheet) {
            AddressSearchView(viewModel: viewModel)
        }
        .sheet(item: $sharePayload) { payload in
            ShareSheet(activityItems: [payload.text, payload.url])
        }
    }

    private var mapSection: some View {
        UIKitMapView(
            rides: [],
            liveCoordinates: viewModel.routeCoordinates,
            liveSegments: viewModel.routeSegments,
            liveSpeedSlices: viewModel.liveSpeedSlices,
            lineColor: RouteLineColor.uiColor(from: trackerColorHex, fallbackHex: RouteLineColor.defaultTrackerHex),
            viewModel: viewModel
        )
        .ignoresSafeArea(edges: [.top, .horizontal])
        .onAppear {
            viewModel.locationService.prepareForForegroundMap()
            viewModel.forceAutoCenter()
        }
    }

    private var rideInfoPlaque: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                Text(LocalizedStringKey("active_ride_title"))
                    .font(Brand.Font.headline)
                    .foregroundStyle(Brand.Color.ink)
                #if DEBUG
                if viewModel.isDeveloperSimulationActive {
                    BrandBadge(
                        title: LocalizedStringKey("developer_simulation_badge"),
                        kind: .custom(.purple)
                    )
                }
                #endif
                Spacer(minLength: 0)
                if let selectedBike {
                    Text(selectedBike.name)
                        .font(Brand.Font.caption)
                        .foregroundStyle(Brand.Color.muted)
                        .lineLimit(1)
                }
                BrandBadge(
                    title: viewModel.isPaused
                        ? LocalizedStringKey("tracking_paused_badge")
                        : LocalizedStringKey("tracking_live_badge"),
                    kind: viewModel.isPaused ? .paused : .live,
                    showsPulse: !viewModel.isPaused
                )
            }

            HStack(spacing: 0) {
                BrandMetric(
                    title: LocalizedStringKey("time_title"),
                    value: viewModel.elapsedTime.formattedAsTimer,
                    size: 22
                )
                metricDivider
                BrandMetric(
                    title: LocalizedStringKey("speed_title"),
                    value: RideFormatters.speed(kmh: viewModel.currentSpeed),
                    size: 22
                )
                metricDivider
                BrandMetric(
                    title: LocalizedStringKey("distance_title"),
                    value: RideFormatters.distance(meters: viewModel.traveledDistance),
                    size: 22
                )
            }

            if viewModel.elevationGain > 0 || sensorService.heartRate != nil || sensorService.cadenceRPM != nil {
                HStack(spacing: 0) {
                    BrandMetric(
                        title: LocalizedStringKey("elevation_title"),
                        value: RideFormatters.elevation(meters: viewModel.elevationGain),
                        size: 18
                    )
                    if let heartRate = sensorService.heartRate {
                        metricDivider
                        BrandMetric(
                            title: LocalizedStringKey("sensors_heart_rate"),
                            value: "\(heartRate)",
                            size: 18
                        )
                    }
                    if let cadence = sensorService.cadenceRPM {
                        metricDivider
                        BrandMetric(
                            title: LocalizedStringKey("sensors_cadence"),
                            value: String(format: "%.0f", cadence),
                            size: 18
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 8)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Brand.Color.hairline)
            .frame(width: 1, height: 36)
    }

    private var bikePicker: some View {
        Menu {
            ForEach(bikes, id: \.id) { bike in
                Button(bike.name) {
                    selectedBikeId = bike.id.uuidString
                }
            }
        } label: {
            Label(selectedBike?.name ?? NSLocalizedString("garage_choose_bike", comment: ""), systemImage: "bicycle")
                .font(Brand.Font.caption)
                .foregroundStyle(Brand.Color.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .liquidGlass(in: Capsule())
        }
    }

    private var mapTools: some View {
        liquidGlassContainer(spacing: 10) {
            VStack(spacing: 10) {
                if viewModel.navigationRoute != nil {
                    GlassMapButton(
                        systemImage: "xmark",
                        accessibilityKey: LocalizedStringKey("clear_route_title")
                    ) {
                        viewModel.clearRoute()
                    }
                }

                if isRideActive {
                    GlassMapButton(
                        systemImage: "square.and.arrow.up",
                        accessibilityKey: LocalizedStringKey("share_location_title")
                    ) {
                        sharePayload = viewModel.makeLocationSharePayload()
                    }
                }

                GlassMapButton(
                    systemImage: "magnifyingglass",
                    accessibilityKey: LocalizedStringKey("search_address_title")
                ) {
                    isShowingSearchSheet = true
                }

                GlassMapButton(
                    systemImage: viewModel.shouldAutoCenter ? "location.fill" : "location",
                    accessibilityKey: LocalizedStringKey("center_map_title")
                ) {
                    viewModel.forceAutoCenter()
                }
            }
        }
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            if !isRideActive {
                GlassActionButton(
                    title: LocalizedStringKey("start_button_title"),
                    systemImage: "play.fill",
                    prominent: true,
                    tint: Brand.Color.ember
                ) {
                    if viewModel.locationService.isDenied {
                        BrandHaptics.warning()
                        return
                    }
                    BrandHaptics.success()
                    viewModel.startTracking()
                }
                .disabled(viewModel.locationService.isDenied)
            } else {
                GlassActionButton(
                    title: viewModel.isPaused
                        ? LocalizedStringKey("resume_button_title")
                        : LocalizedStringKey("pause_button_title"),
                    systemImage: viewModel.isPaused ? "play.fill" : "pause.fill",
                    prominent: viewModel.isPaused,
                    tint: viewModel.isPaused ? Brand.Color.meadow : nil
                ) {
                    if viewModel.isPaused {
                        viewModel.resumeTracking()
                    } else {
                        viewModel.pauseTracking()
                    }
                }

                GlassActionButton(
                    title: LocalizedStringKey("stop_button_title"),
                    systemImage: "stop.fill",
                    tint: Brand.Color.danger
                ) {
                    BrandHaptics.warning()
                    viewModel.requestStopTracking()
                }
            }
        }
    }
}
