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

    init(viewModel: MapViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        _sensorService = ObservedObject(wrappedValue: viewModel.sensorService)
    }

    @AppStorage(.trackerRouteColorKey) private var trackerColorName: String = RouteColor.red.rawValue
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(PreferenceKey.selectedBikeId) private var selectedBikeId = ""

    private var trackerColor: RouteColor {
        RouteColor(rawValue: trackerColorName) ?? .red
    }

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
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer(minLength: 0)

                HStack(alignment: .bottom) {
                    Spacer()
                    mapTools
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                if !isRideActive, !bikes.isEmpty {
                    bikePicker
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                }

                controlButtons
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: isRideActive)
        .animation(.easeInOut(duration: 0.25), value: viewModel.isPaused)
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
            lineColor: trackerColor.uiColor,
            viewModel: viewModel
        )
        .ignoresSafeArea()
        .onAppear {
            viewModel.forceAutoCenter()
        }
    }

    private var rideInfoPlaque: some View {
        VStack(spacing: 12) {
            HStack {
                Text(LocalizedStringKey("active_ride_title"))
                    .font(.subheadline.weight(.semibold))
                #if DEBUG
                if viewModel.isDeveloperSimulationActive {
                    Text(LocalizedStringKey("developer_simulation_badge"))
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.purple.opacity(0.22)))
                        .foregroundStyle(.purple)
                }
                #endif
                Spacer()
                if let selectedBike {
                    Text(selectedBike.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Text(viewModel.isPaused
                     ? LocalizedStringKey("tracking_paused_badge")
                     : LocalizedStringKey("tracking_live_badge"))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule().fill(viewModel.isPaused ? Color.orange.opacity(0.22) : Color.green.opacity(0.22))
                    )
                    .foregroundStyle(viewModel.isPaused ? Color.orange : Color.green)
            }

            HStack(spacing: 0) {
                metricBox(
                    title: LocalizedStringKey("time_title"),
                    value: viewModel.elapsedTime.formattedAsTimer
                )
                metricDivider
                metricBox(
                    title: LocalizedStringKey("speed_title"),
                    value: RideFormatters.speed(kmh: viewModel.currentSpeed)
                )
                metricDivider
                metricBox(
                    title: LocalizedStringKey("distance_title"),
                    value: RideFormatters.distance(meters: viewModel.traveledDistance)
                )
            }

            HStack(spacing: 0) {
                metricBox(
                    title: LocalizedStringKey("elevation_title"),
                    value: RideFormatters.elevation(meters: viewModel.elevationGain)
                )
                if let heartRate = sensorService.heartRate {
                    metricDivider
                    metricBox(
                        title: LocalizedStringKey("sensors_heart_rate"),
                        value: "\(heartRate)"
                    )
                }
                if let cadence = sensorService.cadenceRPM {
                    metricDivider
                    metricBox(
                        title: LocalizedStringKey("sensors_cadence"),
                        value: String(format: "%.0f", cadence)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(width: 1, height: 36)
    }

    private func metricBox(title: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
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
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
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
                    tint: .green
                ) {
                    viewModel.startTracking()
                }
            } else {
                GlassActionButton(
                    title: viewModel.isPaused
                        ? LocalizedStringKey("resume_button_title")
                        : LocalizedStringKey("pause_button_title"),
                    systemImage: viewModel.isPaused ? "play.fill" : "pause.fill",
                    prominent: viewModel.isPaused,
                    tint: viewModel.isPaused ? .green : nil
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
                    tint: .red
                ) {
                    viewModel.requestStopTracking()
                }
            }
        }
    }
}
