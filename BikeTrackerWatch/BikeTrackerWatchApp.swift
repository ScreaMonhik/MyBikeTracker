import SwiftUI

@main
struct BikeTrackerWatchApp: App {
    @StateObject private var session = WatchRideModel()

    var body: some Scene {
        WindowGroup {
            WatchRideView(session: session)
                .onAppear { session.activate() }
        }
    }
}
