//
//  BikeTrackerWidgetLiveActivity.swift
//  BikeTrackerWidget
//
//  Created by Dima Sunko on 06.03.2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Live Activity Widget

struct BikeTrackerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BikeTrackerAttributes.self) { context in
            // MARK: Lock Screen / Notification Banner
            LockScreenLiveActivityView(context: context)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: Dynamic Island – Expanded
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(String(format: "%.1f", context.state.speed))
                            .font(.title2.bold())
                        Text("km/h")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "speedometer")
                            .foregroundStyle(.green)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text(String(format: "%.2f", context.state.distance / 1000))
                            .font(.title2.bold())
                        Text("km")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(.orange)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "bicycle")
                            .foregroundStyle(context.state.isPaused ? .yellow : .green)
                        Text(formattedTime(context.state.elapsedSeconds))
                            .font(.headline.monospacedDigit())
                        if context.state.isPaused {
                            Text("PAUSED")
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.yellow.opacity(0.2), in: Capsule())
                        }
                    }
                }
            } compactLeading: {
                // MARK: Dynamic Island – Compact Leading
                Image(systemName: "bicycle")
                    .foregroundStyle(.green)

            } compactTrailing: {
                // MARK: Dynamic Island – Compact Trailing
                Text(String(format: "%.0f", context.state.speed))
                    .font(.caption.bold().monospacedDigit())
                + Text(" km/h")
                    .font(.system(size: 9))

            } minimal: {
                // MARK: Dynamic Island – Minimal (pill)
                Image(systemName: context.state.isPaused ? "pause.fill" : "bicycle")
                    .foregroundStyle(context.state.isPaused ? .yellow : .green)
            }
            .widgetURL(URL(string: "mybiketracker://tracker"))
            .keylineTint(.green)
        }
    }
}

// MARK: - Lock Screen View

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<BikeTrackerAttributes>

    var body: some View {
        HStack(spacing: 0) {
            // Left – bicycle icon + status
            VStack(spacing: 4) {
                Image(systemName: context.state.isPaused ? "pause.circle.fill" : "bicycle")
                    .font(.system(size: 28))
                    .foregroundStyle(context.state.isPaused ? .yellow : .green)
                Text(context.state.isPaused ? "Paused" : "Riding")
                    .font(.caption2.bold())
                    .foregroundStyle(context.state.isPaused ? .yellow : .green)
            }
            .frame(width: 64)

            Divider()
                .frame(height: 44)
                .padding(.horizontal, 8)

            // Center – speed (most important metric)
            VStack(spacing: 0) {
                Text(String(format: "%.1f", context.state.speed))
                    .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                Text("km/h")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 44)
                .padding(.horizontal, 8)

            // Right – distance + elapsed time
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flag.checkered")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(String(format: "%.2f km", context.state.distance / 1000))
                        .font(.caption.bold().monospacedDigit())
                }
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text(formattedTime(context.state.elapsedSeconds))
                        .font(.caption.bold().monospacedDigit())
                }
            }
            .frame(width: 80, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(.primary)
    }
}

// MARK: - Helpers

private func formattedTime(_ seconds: Int) -> String {
    let h = seconds / 3600
    let m = (seconds % 3600) / 60
    let s = seconds % 60
    if h > 0 {
        return String(format: "%d:%02d:%02d", h, m, s)
    } else {
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Previews

#Preview("Lock Screen", as: .content, using: BikeTrackerAttributes(startDate: .now)) {
    BikeTrackerLiveActivity()
} contentStates: {
    BikeTrackerAttributes.ContentState(elapsedSeconds: 1245, speed: 24.7, distance: 8520, isPaused: false)
    BikeTrackerAttributes.ContentState(elapsedSeconds: 1245, speed: 0, distance: 8520, isPaused: true)
}
