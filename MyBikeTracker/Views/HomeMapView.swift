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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
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
                .ignoresSafeArea()
                .onAppear {
                    viewModel.forceAutoCenter()
                }

                if viewModel.navigationRoute != nil {
                    GlassMapButton(
                        systemImage: "xmark",
                        accessibilityKey: LocalizedStringKey("clear_route_title")
                    ) {
                        viewModel.clearRoute()
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(LocalizedStringKey("map_tab_title"))
            .navigationBarTitleDisplayMode(.inline)
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
