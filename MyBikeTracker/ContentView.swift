//
//  ContentView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import SwiftUI

enum AppTab: Hashable {
    case map
    case trip
    case history
    case settings
}

struct ContentView: View {
    @StateObject var mapViewModel: MapViewModel
    @StateObject var ridesViewModel: RidesViewModel
    @State private var selectedTab: AppTab = .map

    init(mapViewModel: MapViewModel, ridesViewModel: RidesViewModel) {
        _mapViewModel = StateObject(wrappedValue: mapViewModel)
        _ridesViewModel = StateObject(wrappedValue: ridesViewModel)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeMapView(viewModel: mapViewModel, ridesViewModel: ridesViewModel)
                .tabItem {
                    Label(LocalizedStringKey("map_tab_title"), systemImage: "map")
                }
                .tag(AppTab.map)

            TrackerView(viewModel: mapViewModel)
                .tabItem {
                    Label(LocalizedStringKey("trip_tab_title"), systemImage: "bicycle")
                }
                .tag(AppTab.trip)

            HistoryView(ridesViewModel: ridesViewModel)
                .tabItem {
                    Label(LocalizedStringKey("history_tab_title"), systemImage: "list.bullet.rectangle")
                }
                .tag(AppTab.history)

            SettingsView(
                ridesViewModel: ridesViewModel,
                mapViewModel: mapViewModel
            )
            .tabItem {
                Label(LocalizedStringKey("settings_tab_title"), systemImage: "gear")
            }
            .tag(AppTab.settings)
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "mybiketracker",
                  url.host?.lowercased() == "tracker" else { return }
            selectedTab = .trip
        }
        .fullScreenCover(isPresented: $mapViewModel.isEndRideConfirmationPresented) {
            EndRideConfirmationView(
                viewModel: mapViewModel,
                onConfirm: { mapViewModel.confirmStopTracking() },
                onCancel: { mapViewModel.cancelStopTracking() }
            )
        }
    }
}
