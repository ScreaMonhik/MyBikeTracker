//
//  MyBikeTrackerApp.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import SwiftUI
import SwiftData

@main
struct MyBikeTrackerApp: App {
    let container: ModelContainer
    let locationService: LocationService
    let ridesViewModel: RidesViewModel
    let mapViewModel: MapViewModel

    init() {
        let schema = Schema([Ride.self])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            print("Failed to create ModelContainer: \(error). Attempting to recreate the store...")
            let storeURL = modelConfiguration.url
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("shm"))
            try? FileManager.default.removeItem(at: storeURL.appendingPathExtension("wal"))

            do {
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                print("ModelContainer successfully recreated.")
            } catch {
                fatalError("Не удалось создать ModelContainer даже после очистки: \(error)")
            }
        }

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
            ContentView(mapViewModel: mapViewModel, ridesViewModel: ridesViewModel)
        }
        .modelContainer(container)
    }
}
