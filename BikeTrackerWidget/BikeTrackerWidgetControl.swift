import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct BikeTrackerRideControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "dimsun.MyBikeTracker.rideControl") {
            ControlWidgetButton(action: OpenTrackerIntent()) {
                Label("Start Ride", systemImage: "bicycle")
            }
        }
        .displayName("Start Ride")
        .description("Open Trail Dawn to start or continue a bike ride.")
    }
}

struct OpenTrackerIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Ride"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        .result()
    }
}
