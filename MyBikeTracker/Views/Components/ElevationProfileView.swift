import Charts
import SwiftUI

struct ElevationProfileView: View {
    let samples: [ElevationSample]
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("elevation_profile_title"))
                .font(Brand.Font.headline)
                .foregroundStyle(Brand.Color.ink)

            Chart(samples) { sample in
                AreaMark(
                    x: .value("Distance", sample.distance),
                    y: .value("Altitude", displayAltitude(sample.altitude))
                )
                .foregroundStyle(Brand.Color.trail.opacity(0.22))
                LineMark(
                    x: .value("Distance", sample.distance),
                    y: .value("Altitude", displayAltitude(sample.altitude))
                )
                .foregroundStyle(Brand.Color.trail)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let meters = value.as(Double.self) {
                            Text(RideFormatters.distance(meters: meters))
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let altitude = value.as(Double.self) {
                            Text(RideFormatters.elevation(meters: storedAltitude(fromDisplay: altitude)))
                        }
                    }
                }
            }
            .frame(height: 160)
        }
    }

    private func displayAltitude(_ meters: Double) -> Double {
        let system = DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric
        switch system {
        case .metric: return meters
        case .imperial: return meters / RideFormatters.metersPerFoot
        }
    }

    private func storedAltitude(fromDisplay value: Double) -> Double {
        let system = DistanceUnitSystem(rawValue: unitSystemRaw) ?? .metric
        switch system {
        case .metric: return value
        case .imperial: return value * RideFormatters.metersPerFoot
        }
    }
}
