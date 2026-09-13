//
//  SettingsView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @ObservedObject var mapViewModel: MapViewModel

    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex
    @AppStorage(PreferenceKey.healthKitEnabled) private var healthKitEnabled = true
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(PreferenceKey.weeklyGoalKilometers) private var weeklyGoalKilometers = 50.0
    @AppStorage(PreferenceKey.autoPauseSpeedKmh) private var autoPauseSpeedKmh = 1.0
    @AppStorage(PreferenceKey.autoPauseDelaySeconds) private var autoPauseDelaySeconds = 5.0

    private var unitSystem: DistanceUnitSystem {
        DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    private var weeklyGoalBinding: Binding<Double> {
        Binding(
            get: { RideFormatters.weeklyGoalDisplay(kilometers: weeklyGoalKilometers, system: unitSystem) },
            set: { weeklyGoalKilometers = RideFormatters.weeklyGoalKilometers(fromDisplay: $0, system: unitSystem) }
        )
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(Brand.Color.trail.gradient)
                                .frame(width: 52, height: 52)
                            Image(systemName: "figure.outdoor.cycle")
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(Brand.name)
                                .font(Brand.Font.headline)
                                .foregroundStyle(Brand.Color.ink)
                            Text(LocalizedStringKey("brand_tagline"))
                                .font(Brand.Font.micro)
                                .foregroundStyle(Brand.Color.muted)
                            Text(appVersion)
                                .font(Brand.Font.micro)
                                .foregroundStyle(Brand.Color.muted.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker(LocalizedStringKey("units_section"), selection: $unitSystemRaw) {
                        Text(LocalizedStringKey("units_metric")).tag(DistanceUnitSystem.metric.rawValue)
                        Text(LocalizedStringKey("units_imperial")).tag(DistanceUnitSystem.imperial.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: unitSystemRaw) { _, newValue in
                        UnitPreferences.set(DistanceUnitSystem(rawValue: newValue) ?? .metric)
                    }
                } header: {
                    Text(LocalizedStringKey("units_section"))
                } footer: {
                    Text(LocalizedStringKey("units_footer"))
                }

                Section {
                    Stepper(value: weeklyGoalBinding, in: 5...500, step: 5) {
                        Text(RideFormatters.distance(meters: weeklyGoalKilometers * 1000, system: unitSystem))
                            .font(Brand.Font.metric(18))
                    }
                } header: {
                    Text(LocalizedStringKey("weekly_goal_setting"))
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("autopause_speed"))
                        ExclusiveSlider(value: $autoPauseSpeedKmh, range: 0.5...5, step: 0.5)
                        Text(RideFormatters.speed(kmh: autoPauseSpeedKmh, system: unitSystem))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Brand.Color.muted)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("autopause_delay"))
                        ExclusiveSlider(value: $autoPauseDelaySeconds, range: 3...20, step: 1)
                        Text(String(format: NSLocalizedString("autopause_delay_value", comment: ""), Int(autoPauseDelaySeconds)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Brand.Color.muted)
                    }
                } header: {
                    Text(LocalizedStringKey("autopause_section"))
                } footer: {
                    Text(LocalizedStringKey("autopause_footer"))
                }

                Section {
                    NavigationLink {
                        GarageView(ridesViewModel: ridesViewModel)
                    } label: {
                        Label(LocalizedStringKey("garage_section"), systemImage: "bicycle")
                    }
                }

                BluetoothSensorsSection(sensorService: mapViewModel.sensorService)

                Section {
                    StoredRouteColorPicker(
                        title: LocalizedStringKey("history_route_color"),
                        hex: $historyColorHex,
                        fallbackHex: RouteLineColor.defaultHistoryHex
                    )
                } header: {
                    Text(LocalizedStringKey("route_color_section"))
                } footer: {
                    Text(LocalizedStringKey("route_color_footer"))
                }

                Section(header: Text(LocalizedStringKey("healthkit_section"))) {
                    Toggle(LocalizedStringKey("healthkit_toggle"), isOn: $healthKitEnabled)
                        .tint(Brand.Color.trail)
                }

                RideImportExportSection(ridesViewModel: ridesViewModel)

                Section {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(LocalizedStringKey("privacy_policy_title"), systemImage: "hand.raised")
                    }
                    if let url = AppLegal.privacyPolicyURL {
                        Link(destination: url) {
                            Label(LocalizedStringKey("privacy_policy_open_web"), systemImage: "safari")
                        }
                    }
                } header: {
                    Text(LocalizedStringKey("privacy_section"))
                } footer: {
                    Text(LocalizedStringKey("privacy_section_footer"))
                }

                Section {
                    if let crash = ProductAnalytics.shared.lastCrashSummary {
                        Text(crash)
                            .font(Brand.Font.caption)
                            .foregroundStyle(Brand.Color.muted)
                    } else {
                        Text(LocalizedStringKey("diagnostics_no_crashes"))
                            .foregroundStyle(Brand.Color.muted)
                    }
                    Text(LocalizedStringKey("diagnostics_events_footer"))
                        .font(Brand.Font.caption)
                        .foregroundStyle(Brand.Color.muted)
                } header: {
                    Text(LocalizedStringKey("diagnostics_section"))
                }

                #if DEBUG
                DeveloperSettingsSection(
                    mapViewModel: mapViewModel,
                    ridesViewModel: ridesViewModel
                )
                #endif
            }
            .brandListChrome()
            .scrollIndicators(.hidden)
            .navigationTitle(LocalizedStringKey("settings_tab_title"))
            .onAppear {
                UnitPreferences.set(DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric)
            }
        }
    }
}
