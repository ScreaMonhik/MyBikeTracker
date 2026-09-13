import SwiftUI

struct WatchRideView: View {
    @ObservedObject var session: WatchRideModel
    @State private var showStopConfirm = false

    var body: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.title2.monospacedDigit().weight(.bold))
                .minimumScaleFactor(0.7)

            HStack {
                VStack {
                    Text(RideFormatters.speedValue(kmh: session.speed, system: session.unitSystem))
                        .font(.headline.monospacedDigit())
                    Text(RideFormatters.speedUnitLabel(system: session.unitSystem))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack {
                    Text(RideFormatters.distanceValue(meters: session.distance, system: session.unitSystem))
                        .font(.headline.monospacedDigit())
                    Text(RideFormatters.distanceUnitLabel(system: session.unitSystem))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if session.isTracking {
                Button(session.isPaused ? String(localized: "watch_resume") : String(localized: "watch_pause")) {
                    session.togglePause()
                }
                .tint(session.isPaused ? .green : .orange)

                Button(String(localized: "watch_stop"), role: .destructive) {
                    showStopConfirm = true
                }
            } else {
                Button(String(localized: "watch_start")) {
                    session.start()
                }
                .tint(.green)
            }

            if !session.isReachable {
                Text(String(localized: "watch_open_iphone"))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .confirmationDialog(
            String(localized: "watch_end_title"),
            isPresented: $showStopConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "watch_end_save")) {
                session.confirmStop()
            }
            Button(String(localized: "watch_end_discard"), role: .destructive) {
                session.discard()
            }
            Button(String(localized: "watch_cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "watch_end_body"))
        }
    }

    private var formattedTime: String {
        let seconds = Int(session.elapsed)
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
