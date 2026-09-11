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
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex
    @ObservedObject var ridesViewModel: RidesViewModel
    let ride: Ride
    var bikeName: String?

    var body: some View {
        let rideColor = ride.resolvedLineColor(defaultHex: historyColorHex)
        let _ = ridesViewModel.routeStyleRevision
        ScrollView {
            VStack(spacing: 0) {
                Map {
                    ForEach(Array(ride.displaySegments.enumerated()), id: \.offset) { _, coords in
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(rideColor, lineWidth: 3)
                        }
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
                            value: RideFormatters.distance(meters: ride.distance))
                    infoRow(label: LocalizedStringKey("average_speed_title"),
                            value: RideFormatters.speed(kmh: ride.averageSpeed))
                    infoRow(label: LocalizedStringKey("max_speed_title"),
                            value: RideFormatters.speed(kmh: ride.maxSpeed))
                    if ride.resolvedElevationGain > 0 {
                        infoRow(label: LocalizedStringKey("elevation_title"),
                                value: RideFormatters.elevation(meters: ride.resolvedElevationGain))
                    }
                    if let bikeName {
                        infoRow(label: LocalizedStringKey("garage_bike_name"), value: bikeName)
                    }

                    RideLineColorEditor(ride: ride, ridesViewModel: ridesViewModel)
                        .padding(.top, 4)

                    let profile = ride.elevationProfile
                    if profile.count > 1 {
                        ElevationProfileView(samples: profile)
                            .padding(.top, 8)
                    }
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
