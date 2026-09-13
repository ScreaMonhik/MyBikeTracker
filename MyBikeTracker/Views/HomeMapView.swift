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

    private var showsSpeedLegend: Bool {
        ridesViewModel.rides.contains { $0.usesSpeedHeatmapLine }
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
            .overlay(alignment: .top) {
                HStack(alignment: .top) {
                    BrandFloatingChip(
                        title: LocalizedStringKey("map_tab_title"),
                        systemImage: "map.fill"
                    )
                    Spacer()
                    if viewModel.navigationRoute != nil {
                        GlassMapButton(
                            systemImage: "xmark",
                            accessibilityKey: LocalizedStringKey("clear_route_title")
                        ) {
                            viewModel.clearRoute()
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Brand.Space.md)
                .padding(.top, Brand.Space.sm)
                .animation(Brand.Motion.snappy, value: viewModel.navigationRoute != nil)
            }
            .overlay(alignment: .bottomLeading) {
                if showsSpeedLegend {
                    SpeedTrackLegend()
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
