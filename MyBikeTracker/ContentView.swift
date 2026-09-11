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
    @StateObject var nfcService: NFCService
    @State private var selectedTab: AppTab = .map

    init(mapViewModel: MapViewModel, ridesViewModel: RidesViewModel, nfcService: NFCService) {
        _mapViewModel = StateObject(wrappedValue: mapViewModel)
        _ridesViewModel = StateObject(wrappedValue: ridesViewModel)
        _nfcService = StateObject(wrappedValue: nfcService)
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
                mapViewModel: mapViewModel,
                nfcService: nfcService
            )
            .tabItem {
                Label(LocalizedStringKey("settings_tab_title"), systemImage: "gear")
            }
            .tag(AppTab.settings)
        }
        .onOpenURL { url in
            nfcService.handleOpenURL(url)
        }
        .onChange(of: nfcService.latestActivation) { _, activation in
            guard let activation else { return }
            handleNFCTag(activation.tag)
        }
        .fullScreenCover(isPresented: $mapViewModel.isEndRideConfirmationPresented) {
            EndRideConfirmationView(
                viewModel: mapViewModel,
                onConfirm: { mapViewModel.confirmStopTracking() },
                onCancel: { mapViewModel.cancelStopTracking() }
            )
        }
    }

    private func handleNFCTag(_ tag: NFCTagRecord) {
        switch tag.action {
        case .toggleRide:
            if mapViewModel.isRideInProgress {
                selectedTab = .trip
                mapViewModel.requestStopTracking()
            } else {
                mapViewModel.startTracking()
                selectedTab = .trip
            }
        case .startRide:
            if !mapViewModel.isRideInProgress {
                mapViewModel.startTracking()
                selectedTab = .trip
            }
        case .stopRide:
            if mapViewModel.isRideInProgress {
                selectedTab = .trip
                mapViewModel.requestStopTracking()
            }
        }
    }
}
