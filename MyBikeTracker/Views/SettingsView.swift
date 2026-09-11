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

    @AppStorage(.trackerRouteColorKey) private var trackerColorHex: String = RouteLineColor.defaultTrackerHex
    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex
    @AppStorage(PreferenceKey.healthKitEnabled) private var healthKitEnabled = true
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(PreferenceKey.weeklyGoalKilometers) private var weeklyGoalKilometers = 50.0
    @AppStorage(PreferenceKey.autoPauseSpeedKmh) private var autoPauseSpeedKmh = 1.0
    @AppStorage(PreferenceKey.autoPauseDelaySeconds) private var autoPauseDelaySeconds = 5.0

    var body: some View {
        NavigationStack {
            Form {
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
                    Stepper(value: $weeklyGoalKilometers, in: 5...500, step: 5) {
                        Text(RideFormatters.distance(meters: weeklyGoalKilometers * 1000))
                    }
                } header: {
                    Text(LocalizedStringKey("weekly_goal_setting"))
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("autopause_speed"))
                        Slider(value: $autoPauseSpeedKmh, in: 0.5...5, step: 0.5)
                        Text(RideFormatters.speed(kmh: autoPauseSpeedKmh))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("autopause_delay"))
                        Slider(value: $autoPauseDelaySeconds, in: 3...20, step: 1)
                        Text(String(format: NSLocalizedString("autopause_delay_value", comment: ""), Int(autoPauseDelaySeconds)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
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
                        title: LocalizedStringKey("tracker_route_color"),
                        hex: $trackerColorHex,
                        fallbackHex: RouteLineColor.defaultTrackerHex
                    )
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

                // MARK: - Apple Health
                Section(header: Text(LocalizedStringKey("healthkit_section"))) {
                    Toggle(LocalizedStringKey("healthkit_toggle"), isOn: $healthKitEnabled)
                }
                // MARK: - Импорт / Экспорт
                RideImportExportSection(ridesViewModel: ridesViewModel)

                #if DEBUG
                DeveloperSettingsSection(
                    mapViewModel: mapViewModel,
                    ridesViewModel: ridesViewModel
                )
                #endif
            }
            .navigationTitle(LocalizedStringKey("settings_tab_title"))
            .onAppear {
                UnitPreferences.set(DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric)
            }
        }
    }
}
