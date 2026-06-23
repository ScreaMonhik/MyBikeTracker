//
//  ContentView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject var mapViewModel: MapViewModel
    @StateObject var ridesViewModel: RidesViewModel

    init(mapViewModel: MapViewModel, ridesViewModel: RidesViewModel) {
            _mapViewModel = StateObject(wrappedValue: mapViewModel)
            _ridesViewModel = StateObject(wrappedValue: ridesViewModel)
        }
    
    var body: some View {
        TabView {
            HomeMapView(viewModel: mapViewModel, ridesViewModel: ridesViewModel)
                .tabItem {
                    Label(LocalizedStringKey("map_tab_title"), systemImage: "map")
                }

            TrackerView(viewModel: mapViewModel, ridesViewModel: ridesViewModel) // Передаём ridesViewModel сюда
                .tabItem {
                    Label(LocalizedStringKey("trip_tab_title"), systemImage: "bicycle")
                }

            HistoryView(ridesViewModel: ridesViewModel) // Подключаем сюда
                .tabItem {
                    Label(LocalizedStringKey("history_tab_title"), systemImage: "list.bullet.rectangle")
                }

            SettingsView(ridesViewModel: ridesViewModel)
                .tabItem {
                    Label(LocalizedStringKey("settings_tab_title"), systemImage: "gear")
                }
        }
    }
}
