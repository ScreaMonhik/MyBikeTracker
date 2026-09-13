//
//  HomeMapView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI
import CoreLocation

struct HomeMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var ridesViewModel: RidesViewModel
    @State private var ridePopup: RideLinePopupTarget?
    @State private var isRidePopupVisible = false

    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex

    private var heatmapRide: Ride? {
        if isRidePopupVisible, let ride = ridePopup?.ride {
            return ride
        }
        return ridesViewModel.rides.first
    }

    private var showsSpeedLegend: Bool {
        heatmapRide?.hasSpeedHeatmapData == true
    }

    private var heatmapScale: PaceScale {
        guard let ride = heatmapRide else { return .default }
        return ridesViewModel.paceScale(for: ride)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                UIKitMapView(
                    rides: ridesViewModel.rides,
                    lineColor: RouteLineColor.uiColor(from: historyColorHex),
                    defaultRideColorHex: historyColorHex,
                    routeStyleRevision: ridesViewModel.routeStyleRevision,
                    selectedRideID: isRidePopupVisible ? ridePopup?.id : nil,
                    ridePopup: ridePopup,
                    isRidePopupVisible: isRidePopupVisible,
                    ridesViewModel: ridesViewModel,
                    onRideTap: { ride, coordinate in
                        presentPopup(for: ride, at: coordinate)
                    },
                    onEmptyMapTap: {
                        dismissPopup()
                    },
                    viewModel: viewModel
                )
                .ignoresSafeArea(edges: [.top, .horizontal])
                .onAppear {
                    viewModel.locationService.prepareForForegroundMap()
                    viewModel.forceAutoCenter()
                }
            }
            .overlay(alignment: .topTrailing) {
                liquidGlassContainer(spacing: 10) {
                    VStack(spacing: 10) {
                        if viewModel.navigationRoute != nil {
                            GlassMapButton(
                                systemImage: "xmark",
                                accessibilityKey: LocalizedStringKey("clear_route_title")
                            ) {
                                viewModel.clearRoute()
                            }
                            .transition(.scale.combined(with: .opacity))
                        }

                        GlassMapButton(
                            systemImage: viewModel.shouldAutoCenter ? "location.fill" : "location",
                            accessibilityKey: LocalizedStringKey("center_map_title")
                        ) {
                            viewModel.locationService.prepareForForegroundMap()
                            viewModel.forceAutoCenter()
                        }
                    }
                }
                .padding(.horizontal, Brand.Space.md)
                .padding(.top, Brand.Space.sm)
                .animation(Brand.Motion.snappy, value: viewModel.navigationRoute != nil)
            }
            .overlay(alignment: .bottomLeading) {
                if showsSpeedLegend {
                    SpeedTrackLegend(scale: heatmapScale)
                        .padding(.leading, Brand.Space.md)
                        .padding(.bottom, BrandTabBar.contentClearance)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(Brand.Motion.snappy, value: showsSpeedLegend)
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func presentPopup(for ride: Ride, at coordinate: CLLocationCoordinate2D) {
        withAnimation(RideLinePopupMotion.present) {
            ridePopup = RideLinePopupTarget(ride, coordinate: coordinate)
            isRidePopupVisible = true
        }
    }

    private func dismissPopup() {
        guard isRidePopupVisible else { return }
        withAnimation(RideLinePopupMotion.dismiss) {
            isRidePopupVisible = false
        }
    }
}
