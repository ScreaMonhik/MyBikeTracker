import SwiftUI

/// Color well that writes a custom hex onto a completed ride.
struct RideLineColorEditor: View {
    let ride: Ride
    @ObservedObject var ridesViewModel: RidesViewModel
    var compact: Bool = false
    @AppStorage(.historyRouteColorKey) private var defaultHex = RouteLineColor.defaultHistoryHex
    @State private var selection: Color

    init(ride: Ride, ridesViewModel: RidesViewModel, compact: Bool = false) {
        self.ride = ride
        self.ridesViewModel = ridesViewModel
        self.compact = compact
        let fallback = UserDefaults.standard.string(forKey: .historyRouteColorKey)
            ?? RouteLineColor.defaultHistoryHex
        _selection = State(initialValue: ride.resolvedLineColor(defaultHex: fallback))
    }

    var body: some View {
        Group {
            if compact {
                compactEditor
            } else {
                ColorPicker(
                    LocalizedStringKey("ride_line_color"),
                    selection: $selection,
                    supportsOpacity: false
                )
            }

            if ride.hasCustomLineColor {
                Button {
                    ridesViewModel.updateRideLineColor(ride, hex: nil)
                    selection = RouteLineColor.color(from: defaultHex, fallbackHex: defaultHex)
                } label: {
                    if compact {
                        Label(LocalizedStringKey("ride_line_color_reset"), systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.semibold))
                    } else {
                        Text(LocalizedStringKey("ride_line_color_reset"))
                    }
                }
            }
        }
        .onChange(of: selection) { _, newValue in
            let hex = RouteLineColor.hexString(from: newValue)
            guard hex != ride.lineColorHex else { return }
            ridesViewModel.updateRideLineColor(ride, hex: hex)
        }
        .onChange(of: ridesViewModel.routeStyleRevision) { _, _ in
            let resolved = ride.resolvedLineColor(defaultHex: defaultHex)
            if RouteLineColor.hexString(from: selection) != RouteLineColor.hexString(from: resolved) {
                selection = resolved
            }
        }
    }

    private var compactEditor: some View {
        ColorPicker(
            LocalizedStringKey("ride_line_color"),
            selection: $selection,
            supportsOpacity: false
        )
        .font(.subheadline.weight(.medium))
    }
}

/// Compact sheet shown after tapping a ride line on the Map tab.
struct RideLineColorSheet: View {
    let ride: Ride
    @ObservedObject var ridesViewModel: RidesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    RideLineColorEditor(ride: ride, ridesViewModel: ridesViewModel)
                } footer: {
                    Text(LocalizedStringKey("ride_line_color_footer"))
                }

                Section {
                    RideRowView(ride: ride)
                }
            }
            .navigationTitle(LocalizedStringKey("ride_line_color"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(LocalizedStringKey("import_export_alert_ok")) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct StoredRouteColorPicker: View {
    let title: LocalizedStringKey
    @Binding var hex: String
    let fallbackHex: String
    @State private var selection: Color

    init(title: LocalizedStringKey, hex: Binding<String>, fallbackHex: String) {
        self.title = title
        self._hex = hex
        self.fallbackHex = fallbackHex
        _selection = State(initialValue: RouteLineColor.color(from: hex.wrappedValue, fallbackHex: fallbackHex))
    }

    var body: some View {
        ColorPicker(title, selection: $selection, supportsOpacity: false)
            .onChange(of: selection) { _, newValue in
                hex = RouteLineColor.hexString(from: newValue)
            }
            .onChange(of: hex) { _, newValue in
                let resolved = RouteLineColor.color(from: newValue, fallbackHex: fallbackHex)
                if RouteLineColor.hexString(from: selection) != RouteLineColor.hexString(from: resolved) {
                    selection = resolved
                }
            }
    }
}
