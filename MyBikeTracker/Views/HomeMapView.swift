//
//  HomeMapView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI

struct HomeMapView: View {
    @ObservedObject var viewModel: MapViewModel
    @ObservedObject var ridesViewModel: RidesViewModel
    @State private var rideForColorEdit: RideColorTarget?

    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                UIKitMapView(
                    rides: ridesViewModel.rides,
                    lineColor: RouteLineColor.uiColor(from: historyColorHex),
                    defaultRideColorHex: historyColorHex,
                    routeStyleRevision: ridesViewModel.routeStyleRevision,
                    selectedRideID: rideForColorEdit?.id,
                    onRideTap: { ride in
                        rideForColorEdit = RideColorTarget(ride)
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
            .sheet(item: $rideForColorEdit) { target in
                RideLineColorSheet(ride: target.ride, ridesViewModel: ridesViewModel)
            }
        }
    }
}

private struct RideColorTarget: Identifiable {
    let id: UUID
    let ride: Ride

    init(_ ride: Ride) {
        self.id = ride.id
        self.ride = ride
    }
}
