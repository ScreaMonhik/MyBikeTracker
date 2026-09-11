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

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                UIKitMapView(
                    rides: ridesViewModel.rides,
                    lineColor: historyColor.uiColor,
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
}
