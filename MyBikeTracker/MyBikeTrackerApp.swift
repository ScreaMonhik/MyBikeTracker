import SwiftUI
import SwiftData

@main
struct MyBikeTrackerApp: App {
    let container: ModelContainer
    let storeIssue: PersistenceIssue?
    let locationService: LocationService
    let ridesViewModel: RidesViewModel
    let mapViewModel: MapViewModel

    init() {
        let opened = PersistenceController.open()
        container = opened.container
        storeIssue = opened.issue

        Brand.Appearance.configure()
        ProductAnalytics.shared.track(.appLaunch)

        locationService = LocationService()
        ridesViewModel = RidesViewModel(modelContext: container.mainContext)
        let healthKitService = HealthKitService()
        let liveActivityService = LiveActivityService()
        mapViewModel = MapViewModel(
            locationService: locationService,
            ridesViewModel: ridesViewModel,
            healthKitService: healthKitService,
            liveActivityService: liveActivityService
        )
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                mapViewModel: mapViewModel,
                ridesViewModel: ridesViewModel,
                storeIssue: storeIssue
            )
        }
        .modelContainer(container)
    }
}
