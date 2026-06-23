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

    @AppStorage(.historyRouteColorKey) private var historyColorName: String = RouteColor.blue.rawValue

    private var historyColor: RouteColor {
        RouteColor(rawValue: historyColorName) ?? .blue
    }

    private var ridesToDisplay: [Ride] {
        ridesViewModel.rides.map { ride in
            if let matched = ride.matchedRoute, !matched.isEmpty {
                return Ride(
                    route: matched.map { $0.clLocationCoordinate2D },
                    startDate: ride.startDate,
                    endDate: ride.endDate,
                    distance: ride.distance,
                    averageSpeed: ride.averageSpeed,
                    duration: ride.duration
                )
            } else {
                return ride
            }
        }
    }

    var body: some View {
        NavigationView {
            UIKitMapView(rides: ridesToDisplay, lineColor: historyColor.uiColor, viewModel: viewModel)
                .ignoresSafeArea(edges: .top)
                .onAppear {
                    viewModel.forceAutoCenter()
                }
                .navigationTitle(LocalizedStringKey("map_tab_title"))
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}
