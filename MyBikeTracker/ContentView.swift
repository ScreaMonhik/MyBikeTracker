import SwiftUI
import StoreKit

enum AppTab: Hashable, CaseIterable, Identifiable {
    case map
    case trip
    case history
    case settings

    var id: Self { self }
}

struct ContentView: View {
    @StateObject var mapViewModel: MapViewModel
    @StateObject var ridesViewModel: RidesViewModel
    var storeIssue: PersistenceIssue?
    @State private var selectedTab: AppTab = .map
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    init(mapViewModel: MapViewModel, ridesViewModel: RidesViewModel, storeIssue: PersistenceIssue? = nil) {
        _mapViewModel = StateObject(wrappedValue: mapViewModel)
        _ridesViewModel = StateObject(wrappedValue: ridesViewModel)
        self.storeIssue = storeIssue
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeMapView(viewModel: mapViewModel, ridesViewModel: ridesViewModel)
                .hidesSystemTabBar()
                .brandTabBarClearance()
                .tag(AppTab.map)

            TrackerView(viewModel: mapViewModel)
                .hidesSystemTabBar()
                .brandTabBarClearance()
                .tag(AppTab.trip)

            HistoryView(ridesViewModel: ridesViewModel)
                .hidesSystemTabBar()
                .tag(AppTab.history)

            SettingsView(
                ridesViewModel: ridesViewModel,
                mapViewModel: mapViewModel
            )
            .hidesSystemTabBar()
            .tag(AppTab.settings)
        }
        .tint(Brand.Color.trail)
        .background(Brand.Color.canvas)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BrandTabBar(selection: $selectedTab)
        }
        .overlay(alignment: .top) {
            if let storeIssue {
                PersistenceIssueBanner(issue: storeIssue)
            }
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "mybiketracker" else { return }
            switch url.host?.lowercased() {
            case "map": selectedTab = .map
            case "tracker", "trip": selectedTab = .trip
            case "history": selectedTab = .history
            case "settings": selectedTab = .settings
            default: break
            }
        }
        .fullScreenCover(isPresented: $mapViewModel.isEndRideConfirmationPresented) {
            EndRideConfirmationView(
                viewModel: mapViewModel,
                onConfirm: { mapViewModel.confirmStopTracking() },
                onDiscard: { mapViewModel.discardRide() },
                onCancel: { mapViewModel.cancelStopTracking() }
            )
        }
        .alert(
            LocalizedStringKey("store_save_failed_title"),
            isPresented: Binding(
                get: { ridesViewModel.lastSaveError != nil },
                set: { if !$0 { ridesViewModel.lastSaveError = nil } }
            )
        ) {
            Button(LocalizedStringKey("ok_button"), role: .cancel) {}
        } message: {
            Text(ridesViewModel.lastSaveError ?? "")
        }
        .onAppear {
            mapViewModel.restoreInterruptedRideIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            mapViewModel.handleScenePhase(phase)
        }
        .onChange(of: mapViewModel.pendingReviewPrompt) { _, shouldPrompt in
            guard shouldPrompt else { return }
            requestReview()
            mapViewModel.pendingReviewPrompt = false
        }
    }
}
