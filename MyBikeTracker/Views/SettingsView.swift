//
//  SettingsView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var ridesViewModel: RidesViewModel

    @AppStorage(.trackerRouteColorKey) private var trackerColorName: String = RouteColor.red.rawValue
    @AppStorage(.historyRouteColorKey) private var historyColorName: String = RouteColor.blue.rawValue
    @AppStorage("units_metric") private var unitsMetric = true
    @AppStorage("healthkit_enabled") private var healthKitEnabled = true

    var body: some View {
        NavigationView {
            Form {
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

                // MARK: - Apple Health
                Section(header: Text(LocalizedStringKey("healthkit_section"))) {
                    Toggle(LocalizedStringKey("healthkit_toggle"), isOn: $healthKitEnabled)
                }
                // MARK: - Импорт / Экспорт
                RideImportExportSection(ridesViewModel: ridesViewModel)
            }
            .navigationTitle(LocalizedStringKey("settings_tab_title"))
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
