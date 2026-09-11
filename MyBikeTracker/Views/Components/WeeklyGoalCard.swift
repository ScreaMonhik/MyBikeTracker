import SwiftUI

struct WeeklyGoalCard: View {
    let thisWeek: WeekSummary
    let lastWeek: WeekSummary
    @AppStorage(PreferenceKey.weeklyGoalKilometers) private var goalKilometers = 50.0
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var showGoalEditor = false

    private var goalMeters: Double { goalKilometers * 1000 }

    private var progress: Double {
        guard goalMeters > 0 else { return 0 }
        return min(thisWeek.distance / goalMeters, 1)
    }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                showGoalEditor = true
            } label: {
                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text(RideFormatters.distanceValue(meters: thisWeek.distance))
                            .font(.headline.monospacedDigit())
                        Text(RideFormatters.distanceUnitLabel())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 84, height: 84)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(LocalizedStringKey("weekly_goal"))

            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStringKey("weekly_this_week"))
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 16) {
                    labeledValue(LocalizedStringKey("duration_title"), thisWeek.duration.formattedAsTimer)
                    labeledValue(
                        LocalizedStringKey("weekly_rides"),
                        "\(thisWeek.rideCount)"
                    )
                }

                Text(comparisonText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(String(
                    format: NSLocalizedString("weekly_goal_caption", comment: ""),
                    RideFormatters.distance(meters: goalMeters)
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .sheet(isPresented: $showGoalEditor) {
            WeeklyGoalEditor()
        }
    }

    private var comparisonText: String {
        let delta = thisWeek.distance - lastWeek.distance
        if lastWeek.rideCount == 0 && thisWeek.rideCount == 0 {
            return NSLocalizedString("weekly_vs_last_empty", comment: "")
        }
        if delta == 0 {
            return NSLocalizedString("weekly_vs_last_same", comment: "")
        }
        let formatted = RideFormatters.distance(meters: abs(delta))
        let key = delta > 0 ? "weekly_vs_last_up" : "weekly_vs_last_down"
        return String(format: NSLocalizedString(key, comment: ""), formatted)
    }

    private func labeledValue(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
        }
    }
}

struct WeeklyGoalEditor: View {
    @AppStorage(PreferenceKey.weeklyGoalKilometers) private var goalKilometers = 50.0
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @Environment(\.dismiss) private var dismiss

    private var system: DistanceUnitSystem {
        DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    private var displayGoal: Double {
        RideFormatters.weeklyGoalDisplay(kilometers: goalKilometers, system: system)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: Binding(
                        get: { displayGoal },
                        set: { goalKilometers = RideFormatters.weeklyGoalKilometers(fromDisplay: $0, system: system) }
                    ), in: 5...500, step: 5) {
                        Text(RideFormatters.distance(meters: goalKilometers * 1000))
                            .font(.headline.monospacedDigit())
                    }
                } header: {
                    Text(LocalizedStringKey("weekly_goal_setting"))
                } footer: {
                    Text(LocalizedStringKey("weekly_goal_footer"))
                }
            }
            .navigationTitle(LocalizedStringKey("weekly_goal"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("calendar_close")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
