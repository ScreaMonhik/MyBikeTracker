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
            ZStack(alignment: .topTrailing) {
                UIKitMapView(rides: ridesToDisplay, lineColor: historyColor.uiColor, viewModel: viewModel)
                    .ignoresSafeArea()
                    .onAppear {
                        viewModel.forceAutoCenter()
                    }

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
                    .padding(.trailing, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(LocalizedStringKey("map_tab_title"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
