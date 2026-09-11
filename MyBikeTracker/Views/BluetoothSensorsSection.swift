import SwiftUI

struct BluetoothSensorsSection: View {
    @ObservedObject var sensorService: BluetoothSensorService

    var body: some View {
        Section {
            if let name = sensorService.heartRateName {
                HStack {
                    Label(name, systemImage: "heart.fill")
                    Spacer()
                    if let hr = sensorService.heartRate {
                        Text("\(hr)")
                            .font(.body.monospacedDigit())
                    }
                    Button(LocalizedStringKey("sensors_disconnect"), role: .destructive) {
                        sensorService.disconnectHeartRate()
                    }
                    .font(.caption)
                }
            }

            if let name = sensorService.cadenceName {
                HStack {
                    Label(name, systemImage: "circle.hexagonpath")
                    Spacer()
                    if let cadence = sensorService.cadenceRPM {
                        Text(String(format: "%.0f", cadence))
                            .font(.body.monospacedDigit())
                    }
                    Button(LocalizedStringKey("sensors_disconnect"), role: .destructive) {
                        sensorService.disconnectCadence()
                    }
                    .font(.caption)
                }
            }

            if sensorService.isScanning {
                Button(LocalizedStringKey("sensors_stop_scan")) {
                    sensorService.stopScan()
                }
            } else {
                Button(LocalizedStringKey("sensors_scan")) {
                    sensorService.startScan()
                }
                .disabled(!sensorService.isPoweredOn)
            }

            ForEach(sensorService.discovered) { sensor in
                Button {
                    sensorService.connect(sensor)
                } label: {
                    HStack {
                        Image(systemName: icon(for: sensor.kind))
                        Text(sensor.name)
                        Spacer()
                        Text(kindLabel(sensor.kind))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Stepper(value: $sensorService.wheelCircumferenceMm, in: 1500...2400, step: 5) {
                Text(String(
                    format: NSLocalizedString("sensors_wheel_circumference", comment: ""),
                    Int(sensorService.wheelCircumferenceMm)
                ))
            }
        } header: {
            Text(LocalizedStringKey("sensors_section"))
        } footer: {
            Text(LocalizedStringKey("sensors_footer"))
        }
    }

    private func icon(for kind: DiscoveredSensor.Kind) -> String {
        switch kind {
        case .heartRate: return "heart"
        case .cadence: return "circle.hexagonpath"
        case .both: return "antenna.radiowaves.left.and.right"
        }
    }

    private func kindLabel(_ kind: DiscoveredSensor.Kind) -> String {
        switch kind {
        case .heartRate: return NSLocalizedString("sensors_heart_rate", comment: "")
        case .cadence: return NSLocalizedString("sensors_cadence", comment: "")
        case .both: return NSLocalizedString("sensors_both", comment: "")
        }
    }
}
