import SwiftUI

struct WatchRideView: View {
    @ObservedObject var session: WatchRideModel

    var body: some View {
        VStack(spacing: 8) {
            Text(formattedTime)
                .font(.title2.monospacedDigit().weight(.bold))

            HStack {
                VStack {
                    Text(String(format: "%.1f", session.speed))
                        .font(.headline.monospacedDigit())
                    Text("km/h")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack {
                    Text(String(format: "%.2f", session.distance / 1000))
                        .font(.headline.monospacedDigit())
                    Text("km")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if session.isTracking {
                Button(session.isPaused ? "Resume" : "Pause") {
                    session.togglePause()
                }
                .tint(session.isPaused ? .green : .orange)

                Button("Stop", role: .destructive) {
                    session.stop()
                }
            } else {
                Button("Start") {
                    session.start()
                }
                .tint(.green)
            }

            if !session.isReachable {
                Text("Open iPhone app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
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
