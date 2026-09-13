import SwiftUI

struct GarageView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @AppStorage(PreferenceKey.selectedBikeId) private var selectedBikeId = ""
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var showAddBike = false
    @State private var editingPaceBikeID: UUID?

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
        .sheet(isPresented: Binding(
            get: { editingPaceBikeID != nil },
            set: { if !$0 { editingPaceBikeID = nil } }
        )) {
            if let id = editingPaceBikeID,
               let bike = ridesViewModel.bikes.first(where: { $0.id == id }) {
                BikePaceSettingsSheet(bike: bike, ridesViewModel: ridesViewModel)
            }
        }
    }

    @ViewBuilder
    private func bikeRow(_ bike: Bike) -> some View {
        let progress = bike.chainIntervalMeters > 0
            ? min(bike.metersSinceChainService / bike.chainIntervalMeters, 1)
            : 0
        let isSelected = selectedBikeId == bike.id.uuidString

        VStack(alignment: .leading, spacing: 12) {
            Button {
                selectedBikeId = bike.id.uuidString
                BrandHaptics.select()
            } label: {
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
                        if isSelected {
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
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bike.name)
            .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

            HStack {
                Button(LocalizedStringKey("garage_chain_reset")) {
                    ridesViewModel.resetChain(for: bike)
                    BrandHaptics.success()
                }

                Spacer()

                Button {
                    editingPaceBikeID = bike.id
                } label: {
                    Label(LocalizedStringKey("garage_pace_title"), systemImage: "speedometer")
                }
            }
            .font(Brand.Font.caption)
            .tint(Brand.Color.trail)
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 6)
    }
}

struct BikePaceSettingsSheet: View {
    let bike: Bike
    @ObservedObject var ridesViewModel: RidesViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue

    @State private var slowMaxKmh: Double
    @State private var mediumMaxKmh: Double

    init(bike: Bike, ridesViewModel: RidesViewModel) {
        self.bike = bike
        self.ridesViewModel = ridesViewModel
        let scale = bike.paceScale
        _slowMaxKmh = State(initialValue: scale.slowMaxKmh)
        _mediumMaxKmh = State(initialValue: scale.mediumMaxKmh)
    }

    private var system: DistanceUnitSystem {
        DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("garage_pace_slow_max"))
                        ExclusiveSlider(value: $slowMaxKmh, range: 5...45, step: 1)
                        Text(RideFormatters.speed(kmh: slowMaxKmh, system: system))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Brand.Color.muted)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStringKey("garage_pace_medium_max"))
                        ExclusiveSlider(value: $mediumMaxKmh, range: 8...55, step: 1)
                        Text(RideFormatters.speed(kmh: mediumMaxKmh, system: system))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Brand.Color.muted)
                    }
                    LabeledContent(LocalizedStringKey("garage_pace_fast_from")) {
                        Text(RideFormatters.speed(kmh: mediumMaxKmh, system: system))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(Brand.Color.muted)
                    }
                } header: {
                    Text(bike.name)
                } footer: {
                    Text(LocalizedStringKey("garage_pace_footer"))
                }
            }
            .scrollIndicators(.hidden)
            .tint(Brand.Color.trail)
            .navigationTitle(LocalizedStringKey("garage_pace_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("calendar_close")) {
                        persist()
                        dismiss()
                    }
                }
            }
            .onChange(of: slowMaxKmh) { _, newValue in
                if newValue >= mediumMaxKmh {
                    mediumMaxKmh = min(55, newValue + 2)
                }
            }
            .onChange(of: mediumMaxKmh) { _, newValue in
                if newValue <= slowMaxKmh {
                    slowMaxKmh = max(5, newValue - 2)
                }
            }
        }
        .presentationDetents([.medium])
        .onDisappear {
            persist()
        }
    }

    private func persist() {
        let scale = PaceScale(slowMaxKmh: slowMaxKmh, mediumMaxKmh: mediumMaxKmh).sanitized
        guard abs(bike.paceSlowMaxKmh - scale.slowMaxKmh) > 0.01
            || abs(bike.paceMediumMaxKmh - scale.mediumMaxKmh) > 0.01 else { return }
        ridesViewModel.updateBikePace(bike, slowMaxKmh: scale.slowMaxKmh, mediumMaxKmh: scale.mediumMaxKmh)
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
