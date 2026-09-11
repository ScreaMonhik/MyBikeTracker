#if DEBUG
import SwiftUI

struct DeveloperSettingsSection: View {
    @ObservedObject var mapViewModel: MapViewModel
    @ObservedObject var ridesViewModel: RidesViewModel
    @ObservedObject var nfcService: NFCService

    @State private var seedMessage: String?

    var body: some View {
        Section {
            Button {
                mapViewModel.startDeveloperSimulatedRide()
            } label: {
                Label(LocalizedStringKey("developer_start_moving_ride"), systemImage: "figure.outdoor.cycle")
            }

            Button {
                mapViewModel.startDeveloperPausedRide()
            } label: {
                Label(LocalizedStringKey("developer_start_paused_ride"), systemImage: "pause.circle")
            }

            Button {
                mapViewModel.stopDeveloperSimulationKeepingRide()
            } label: {
                Label(LocalizedStringKey("developer_stop_simulation"), systemImage: "dot.scope")
            }
            .disabled(!mapViewModel.isDeveloperSimulationActive)

            Button {
                nfcService.simulateTap(action: .toggleRide)
            } label: {
                Label(LocalizedStringKey("developer_simulate_nfc"), systemImage: "wave.3.right")
            }

            Button {
                let before = ridesViewModel.rides.count
                mapViewModel.seedDeveloperSampleRides()
                let added = ridesViewModel.rides.count - before
                seedMessage = String(
                    format: NSLocalizedString("developer_seed_result", comment: ""),
                    Int64(added)
                )
            } label: {
                Label(LocalizedStringKey("developer_seed_rides"), systemImage: "calendar.badge.plus")
            }
        } header: {
            Text(LocalizedStringKey("developer_section"))
        } footer: {
            Text(seedMessage ?? NSLocalizedString("developer_section_footer", comment: ""))
        }
    }
}
#endif
