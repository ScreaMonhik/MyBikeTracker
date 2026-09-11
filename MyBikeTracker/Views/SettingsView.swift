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
    @ObservedObject var nfcService: NFCService

    @AppStorage(.trackerRouteColorKey) private var trackerColorName: String = RouteColor.red.rawValue
    @AppStorage(.historyRouteColorKey) private var historyColorName: String = RouteColor.blue.rawValue
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

                // MARK: - Цвет линий
                Section(header: Text("Цвет маршрута")) {
                    colorPickerRow(
                        title: "Во время поездки",
                        selectedColorName: $trackerColorName,
                        defaultColor: .red
                    )

                    colorPickerRow(
                        title: "На общей карте",
                        selectedColorName: $historyColorName,
                        defaultColor: .blue
                    )
                }

                NFCTagsSettingsSection(nfcService: nfcService)

                // MARK: - Apple Health
                Section(header: Text(LocalizedStringKey("healthkit_section"))) {
                    Toggle(LocalizedStringKey("healthkit_toggle"), isOn: $healthKitEnabled)
                }
                // MARK: - Импорт / Экспорт
                RideImportExportSection(ridesViewModel: ridesViewModel)

                #if DEBUG
                DeveloperSettingsSection(
                    mapViewModel: mapViewModel,
                    ridesViewModel: ridesViewModel,
                    nfcService: nfcService
                )
                #endif
            }
            .navigationTitle(LocalizedStringKey("settings_tab_title"))
            .onAppear {
                UnitPreferences.set(DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric)
            }
        }
    }

    // MARK: - Color Picker Row

    @ViewBuilder
    private func colorPickerRow(
        title: LocalizedStringKey,
        selectedColorName: Binding<String>,
        defaultColor: RouteColor
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                Spacer()
                // Превью выбранного цвета
                let selected = RouteColor(rawValue: selectedColorName.wrappedValue) ?? defaultColor
                Circle()
                    .fill(selected.color)
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 1))
            }

            // Сетка цветов
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 10) {
                ForEach(RouteColor.allCases) { option in
                    let isSelected = selectedColorName.wrappedValue == option.rawValue
                    Button(action: {
                        selectedColorName.wrappedValue = option.rawValue
                    }) {
                        Circle()
                            .fill(option.color)
                            .frame(width: 32, height: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary, lineWidth: isSelected ? 3 : 0)
                                    .padding(-3)
                            )
                            .shadow(color: option.color.opacity(0.5), radius: isSelected ? 4 : 0)
                            .scaleEffect(isSelected ? 1.15 : 1.0)
                            .animation(.spring(response: 0.25), value: isSelected)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.vertical, 4)
    }
}
