import SwiftUI

struct WeeklyGoalCard: View {
    let thisWeek: WeekSummary
    let lastWeek: WeekSummary
    @AppStorage(PreferenceKey.weeklyGoalKilometers) private var goalKilometers = 50.0
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var showGoalEditor = false
    @State private var animatedProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var goalMeters: Double { goalKilometers * 1000 }

    private var progress: Double {
        guard goalMeters > 0 else { return 0 }
        return min(thisWeek.distance / goalMeters, 1)
    }

    var body: some View {
        BrandCard {
            HStack(spacing: 16) {
                Button {
                    showGoalEditor = true
                } label: {
                    ZStack {
                        Circle()
                            .stroke(Brand.Color.surfaceMuted, lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: animatedProgress)
                            .stroke(
                                Brand.Color.trail.gradient,
                                style: StrokeStyle(lineWidth: 9, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 1) {
                            Text(RideFormatters.distanceValue(meters: thisWeek.distance))
                                .font(Brand.Font.metric(18))
                                .foregroundStyle(Brand.Color.ink)
                            Text(RideFormatters.distanceUnitLabel())
                                .font(Brand.Font.micro)
                                .foregroundStyle(Brand.Color.muted)
                        }
                    }
                    .frame(width: 92, height: 92)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(LocalizedStringKey("weekly_goal"))

                VStack(alignment: .leading, spacing: 10) {
                    Text(LocalizedStringKey("weekly_this_week"))
                        .font(Brand.Font.headline)
                        .foregroundStyle(Brand.Color.ink)

                    HStack(spacing: 16) {
                        BrandMetric(
                            title: LocalizedStringKey("duration_title"),
                            value: thisWeek.duration.formattedAsTimer,
                            size: 16,
                            alignment: .leading
                        )
                        BrandMetric(
                            title: LocalizedStringKey("weekly_rides"),
                            value: "\(thisWeek.rideCount)",
                            size: 16,
                            alignment: .leading
                        )
                    }

                    Text(comparisonText)
                        .font(Brand.Font.micro)
                        .foregroundStyle(Brand.Color.muted)

                    Text(String(
                        format: NSLocalizedString("weekly_goal_caption", comment: ""),
                        RideFormatters.distance(meters: goalMeters)
                    ))
                    .font(Brand.Font.micro)
                    .foregroundStyle(Brand.Color.trail)
                }
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : Brand.Motion.ring) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(Brand.Motion.soft) {
                animatedProgress = newValue
            }
        }
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
                            .font(Brand.Font.metric(22))
                    }
                } header: {
                    Text(LocalizedStringKey("weekly_goal_setting"))
                } footer: {
                    Text(LocalizedStringKey("weekly_goal_footer"))
                }
            }
            .tint(Brand.Color.trail)
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
