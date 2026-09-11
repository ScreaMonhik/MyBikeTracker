import SwiftUI

struct RideRowView: View {
    let ride: Ride
    var showsDate: Bool = true

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
            metric(
                LocalizedStringKey("distance_title"),
                String(format: "%.2f %@", ride.distance / 1000, NSLocalizedString("distance_unit", comment: ""))
            )
            metric(
                LocalizedStringKey("average_speed_title"),
                String(format: "%.1f %@", ride.averageSpeed, NSLocalizedString("speed_unit", comment: ""))
            )
            metric(
                LocalizedStringKey("max_speed_title"),
                String(format: "%.1f %@", ride.maxSpeed, NSLocalizedString("speed_unit", comment: ""))
            )
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
