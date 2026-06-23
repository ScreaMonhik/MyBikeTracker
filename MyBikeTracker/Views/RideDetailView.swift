//
//  RideDetailView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI
import MapKit

struct RideDetailView: View {
    @State private var currentRegion: MKCoordinateRegion?
    let ride: Ride

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Map {
                    if let matched = ride.matchedRoute, matched.count > 1 {
                        let coords = matched.map { $0.clLocationCoordinate2D }
                        MapPolyline(coordinates: coords)
                            .stroke(Color.blue.opacity(0.8), lineWidth: 3)
                    } else if ride.route.count > 1 {
                        MapPolyline(coordinates: ride.route.map { $0.clLocationCoordinate2D })
                            .stroke(Color.orange.opacity(0.8), lineWidth: 3)
                    }
                }
                .frame(height: 300)
                .onMapCameraChange { context in
                    currentRegion = context.region
                }

                VStack(alignment: .leading, spacing: 12) {
                    infoRow(label: LocalizedStringKey("start_date_title"),
                            value: ride.startDate.formatted(date: .long, time: .shortened))
                    infoRow(label: LocalizedStringKey("duration_title"),
                            value: ride.duration.formattedAsTimer)
                    infoRow(label: LocalizedStringKey("distance_title"),
                            value: String(format: "%.2f %@", ride.distance / 1000, NSLocalizedString("distance_unit", comment: "")))
                    infoRow(label: LocalizedStringKey("average_speed_title"),
                            value: String(format: "%.1f %@", ride.averageSpeed, NSLocalizedString("speed_unit", comment: "")))
                    infoRow(label: LocalizedStringKey("max_speed_title"),
                            value: String(format: "%.1f %@", ride.maxSpeed, NSLocalizedString("speed_unit", comment: "")))
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(LocalizedStringKey("ride_details"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 4)
            Divider()
        }
    }
}
