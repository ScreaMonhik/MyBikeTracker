import SwiftUI

struct GarageView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @AppStorage(PreferenceKey.selectedBikeId) private var selectedBikeId = ""
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var showAddBike = false

    var body: some View {
        Group {
            if ridesViewModel.bikes.isEmpty {
                BrandEmptyState(
                    title: LocalizedStringKey("garage_no_bikes"),
                    message: LocalizedStringKey("garage_no_bikes_message")
                )
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .brandScreen()
            } else {
                List {
                    ForEach(ridesViewModel.bikes, id: \.id) { bike in
                        bikeRow(bike)
                            .brandListCard()
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            ridesViewModel.deleteBike(ridesViewModel.bikes[index])
                        }
                    }
                }
                .listStyle(.plain)
                .brandListChrome()
                .brandListGutter()
            }
        }
        .navigationTitle(LocalizedStringKey("garage_section"))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddBike = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.semibold)
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
        let progress = bike.chainIntervalMeters > 0
            ? min(bike.metersSinceChainService / bike.chainIntervalMeters, 1)
            : 0

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bike.name)
                        .font(Brand.Font.headline)
                        .foregroundStyle(Brand.Color.ink)
                    Text(RideFormatters.distance(meters: bike.odometerMeters))
                        .font(Brand.Font.metric(16))
                        .foregroundStyle(Brand.Color.muted)
                }
                Spacer()
                if selectedBikeId == bike.id.uuidString {
                    BrandBadge(title: LocalizedStringKey("garage_selected"), kind: .live)
                }
            }

            ProgressView(value: progress)
                .tint(bike.isChainDue ? Brand.Color.amber : Brand.Color.trail)

            if bike.isChainDue {
                Label(LocalizedStringKey("garage_chain_due"), systemImage: "wrench.and.screwdriver")
                    .font(Brand.Font.caption)
                    .foregroundStyle(Brand.Color.amber)
            } else {
                Text(String(
                    format: NSLocalizedString("garage_chain_remaining", comment: ""),
                    RideFormatters.distance(meters: max(0, bike.chainIntervalMeters - bike.metersSinceChainService))
                ))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.muted)
            }

            HStack {
                Button(LocalizedStringKey("garage_use_bike")) {
                    selectedBikeId = bike.id.uuidString
                    BrandHaptics.select()
                }
                .disabled(selectedBikeId == bike.id.uuidString)

                Button(LocalizedStringKey("garage_chain_reset")) {
                    ridesViewModel.resetChain(for: bike)
                    BrandHaptics.success()
                }
            }
            .font(Brand.Font.caption)
            .tint(Brand.Color.trail)
        }
        .padding(.vertical, 6)
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
                        .foregroundStyle(Brand.Color.muted)
                }
                HStack {
                    Text(LocalizedStringKey("garage_chain_interval"))
                    Spacer()
                    TextField("400", value: $chainDisplay, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Text(RideFormatters.distanceUnitLabel())
                        .foregroundStyle(Brand.Color.muted)
                }
            }
            .tint(Brand.Color.trail)
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
