//
//  TrackerView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI
import MapKit
import CoreLocation

struct TrackerView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var ridesViewModel: RidesViewModel
    @State private var showStopConfirmation: Bool = false
    @State private var isShowingSearchSheet: Bool = false

    @AppStorage(.trackerRouteColorKey) private var trackerColorName: String = RouteColor.red.rawValue

    private var trackerColor: RouteColor {
        RouteColor(rawValue: trackerColorName) ?? .red
    }

    var body: some View {
        ZStack {
            mapSection

            VStack {
                if viewModel.startTime != nil {
                    metricsPanel
                        .transition(.opacity.combined(with: .slide))
                }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .animation(.easeInOut(duration: 0.7), value: viewModel.startTime)

            VStack {
                Spacer()

                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        if viewModel.navigationRoute != nil {
                            Button(action: {
                                viewModel.clearRoute()
                            }) {
                                Image(systemName: "xmark") // Keep existing icon
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .frame(width: 50, height: 50)
                                    .background(ChromeGlass(cornerRadius: 25))
                                    .overlay(
                                        Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                    )
                            }
                            .buttonStyle(.plain)
                            .fixedSize() // CRITICAL: Prevents greedy expansion
                        }

                        Button(action: {
                            isShowingSearchSheet = true
                        }) {
                            Image(systemName: "magnifyingglass") // Keep existing icon
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 50, height: 50)
                                .background(ChromeGlass(cornerRadius: 25))
                                .overlay(
                                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .fixedSize() // CRITICAL: Prevents greedy expansion

                        Button(action: {
                            viewModel.forceAutoCenter()
                        }) {
                            Image(systemName: "location.fill") // Keep existing icon
                                .font(.title2.weight(.semibold))
                                .foregroundColor(.primary)
                                .frame(width: 50, height: 50)
                                .background(ChromeGlass(cornerRadius: 25))
                                .overlay(
                                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                                )
                        }
                        .buttonStyle(.plain)
                        .fixedSize() // CRITICAL: Prevents greedy expansion
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 100)
                }

                controlButtons
            }
        }
        .sheet(isPresented: $isShowingSearchSheet) {
            AddressSearchView(viewModel: viewModel)
        }
    }

    private var mapSection: some View {
        let currentRide = Ride(
            route: viewModel.route.map { $0.coordinate },
            startDate: viewModel.startTime ?? Date(),
            endDate: Date(),
            distance: viewModel.traveledDistance,
            averageSpeed: viewModel.averageSpeed,
            duration: viewModel.elapsedTime
        )
        return UIKitMapView(rides: [currentRide], lineColor: trackerColor.uiColor, viewModel: viewModel)
            .onAppear {
                viewModel.forceAutoCenter()
            }
            .ignoresSafeArea()
    }

    private var metricsPanel: some View {
        HStack(spacing: 16) {
            metricBox(title: LocalizedStringKey("time_title"), value: viewModel.elapsedTime.formattedAsTimer)
            metricBox(title: LocalizedStringKey("speed_title"), value: String(format: "%.1f км/ч", viewModel.currentSpeed))
            metricBox(title: LocalizedStringKey("distance_title"), value: String(format: "%.2f км", viewModel.traveledDistance / 1000))
        }
        .padding()
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 12)
        )
        .environment(\.colorScheme, .dark)
        .padding()
    }

    private func metricBox(title: LocalizedStringKey, value: String) -> some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(width: 100, height: 50)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var controlButtons: some View {
        HStack {
            if viewModel.startTime == nil {
                Button(action: {
                    viewModel.startTracking()
                }) {
                    Label(LocalizedStringKey("start_button_title"), systemImage: "play.fill") // Keep existing label
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(ChromeGlass(cornerRadius: 24))
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .fixedSize() // CRITICAL: Prevents greedy expansion

            } else {
                Button(action: {
                    if viewModel.isPaused {
                        viewModel.resumeTracking()
                    } else {
                        viewModel.pauseTracking()
                    }
                }) {
                    Label(viewModel.isPaused ? LocalizedStringKey("resume_button_title") : LocalizedStringKey("pause_button_title"),
                          systemImage: viewModel.isPaused ? "play.fill" : "pause.fill") // Keep existing label
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(ChromeGlass(cornerRadius: 24))
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .fixedSize() // CRITICAL: Prevents greedy expansion

                Button(action: {
                    showStopConfirmation = true
                }) {
                    Label(LocalizedStringKey("stop_button_title"), systemImage: "stop.fill") // Keep existing label
                        .font(.headline.weight(.semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(ChromeGlass(cornerRadius: 24))
                        .overlay(
                            Capsule().strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)
                .fixedSize() // CRITICAL: Prevents greedy expansion
            }
        }
        .padding(.bottom)
        .alert(LocalizedStringKey("stop_ride_confirmation"), isPresented: $showStopConfirmation) {
            Button(LocalizedStringKey("yes"), role: .destructive) {
                viewModel.stopTracking()
            }
            Button(LocalizedStringKey("no"), role: .cancel) {}
        } message: {
            Text(LocalizedStringKey("stop_ride_confirmation_message"))
        }
    }
}
