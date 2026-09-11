import SwiftUI

struct RideRowView: View {
    let ride: Ride
    var showsDate: Bool = true
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showsDate {
                HStack {
                    Text(LocalizedStringKey("ride_from"))
                    Text(ride.startDate.formatted(date: .abbreviated, time: .shortened))
                        .fontWeight(.semibold)
                }
            } else {
                Text(ride.startDate.formatted(date: .omitted, time: .shortened))
                    .fontWeight(.semibold)
            }

            metric(LocalizedStringKey("duration_title"), ride.duration.formattedAsTimer)
            metric(LocalizedStringKey("distance_title"), RideFormatters.distance(meters: ride.distance))
            metric(LocalizedStringKey("average_speed_title"), RideFormatters.speed(kmh: ride.averageSpeed))
            metric(LocalizedStringKey("max_speed_title"), RideFormatters.speed(kmh: ride.maxSpeed))
            if ride.resolvedElevationGain > 0 {
                metric(LocalizedStringKey("elevation_title"), RideFormatters.elevation(meters: ride.resolvedElevationGain))
            }
        }
        .padding(.vertical, 4)
    }

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
