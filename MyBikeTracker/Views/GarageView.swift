import SwiftUI

struct GarageView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @AppStorage(PreferenceKey.selectedBikeId) private var selectedBikeId = ""
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var showAddBike = false

    var body: some View {
        List {
            if ridesViewModel.bikes.isEmpty {
                ContentUnavailableView(
                    LocalizedStringKey("garage_no_bikes"),
                    systemImage: "bicycle",
                    description: Text(LocalizedStringKey("garage_no_bikes_message"))
                )
            } else {
                ForEach(ridesViewModel.bikes, id: \.id) { bike in
                    bikeRow(bike)
                }
                .onDelete { offsets in
                    for index in offsets {
                        ridesViewModel.deleteBike(ridesViewModel.bikes[index])
                    }
                }
            }
        }
        .navigationTitle(LocalizedStringKey("garage_section"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddBike = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(LocalizedStringKey("garage_add_bike"))
            }
        }
        .sheet(isPresented: $showAddBike) {
            AddBikeSheet(ridesViewModel: ridesViewModel)
        }
    }

    @ViewBuilder
    private func bikeRow(_ bike: Bike) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(bike.name)
                    .font(.headline)
                Spacer()
                if selectedBikeId == bike.id.uuidString {
                    Text(LocalizedStringKey("garage_selected"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Text(RideFormatters.distance(meters: bike.odometerMeters))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            if bike.isChainDue {
                Label(LocalizedStringKey("garage_chain_due"), systemImage: "wrench.and.screwdriver")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
            } else {
                Text(String(
                    format: NSLocalizedString("garage_chain_remaining", comment: ""),
                    RideFormatters.distance(meters: max(0, bike.chainIntervalMeters - bike.metersSinceChainService))
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            HStack {
                Button(LocalizedStringKey("garage_use_bike")) {
                    selectedBikeId = bike.id.uuidString
                }
                .disabled(selectedBikeId == bike.id.uuidString)

                Button(LocalizedStringKey("garage_chain_reset")) {
                    ridesViewModel.resetChain(for: bike)
                }
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

private struct AddBikeSheet: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue

    @State private var name = ""
    @State private var odometerDisplay = 0.0
    @State private var chainDisplay = 400.0

    private var system: DistanceUnitSystem {
        DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField(LocalizedStringKey("garage_bike_name"), text: $name)
                HStack {
                    Text(LocalizedStringKey("garage_odometer"))
                    Spacer()
                    TextField("0", value: $odometerDisplay, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(RideFormatters.distanceUnitLabel())
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Text(LocalizedStringKey("garage_chain_interval"))
                    Spacer()
                    TextField("400", value: $chainDisplay, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(RideFormatters.distanceUnitLabel())
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(LocalizedStringKey("garage_add_bike"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(LocalizedStringKey("no")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("yes")) {
                        ridesViewModel.addBike(
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            odometerMeters: meters(from: odometerDisplay),
                            chainIntervalMeters: meters(from: chainDisplay)
                        )
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func meters(from display: Double) -> Double {
        switch system {
        case .metric: return display * 1000
        case .imperial: return display * RideFormatters.metersPerMile
        }
    }
}
