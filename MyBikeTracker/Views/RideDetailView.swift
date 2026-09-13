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
        let speedSlices = ride.speedColoredSlices
        let usesSpeedHeatmap = speedSlices.contains { $0.coordinates.count > 1 }
        let _ = ridesViewModel.routeStyleRevision
        ScrollView {
            VStack(spacing: 16) {
                Map {
                    if usesSpeedHeatmap {
                        speedTrackMapContent(slices: speedSlices)
                    } else {
                        ForEach(Array(ride.displaySegments.enumerated()), id: \.offset) { _, coords in
                            if coords.count > 1 {
                                MapPolyline(coordinates: coords)
                                    .stroke(rideColor, lineWidth: 4)
                            }
                        }
                    }
                }
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: Brand.Radius.lg, style: .continuous)
                        .strokeBorder(Brand.Color.hairline, lineWidth: 1)
                }
                .onMapCameraChange { context in
                    currentRegion = context.region
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if usesSpeedHeatmap {
                    HStack(spacing: 8) {
                        Text(LocalizedStringKey("speed_legend_slow"))
                        LinearGradient(
                            colors: SpeedHeatmap.legendColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(height: 6)
                        .clipShape(Capsule())
                        Text(LocalizedStringKey("speed_legend_fast"))
                    }
                    .font(Brand.Font.micro)
                    .foregroundStyle(Brand.Color.muted)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(LocalizedStringKey("speed_legend_accessibility"))
                }

                BrandCard {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        BrandMetric(
                            title: LocalizedStringKey("distance_title"),
                            value: RideFormatters.distance(meters: ride.distance),
                            size: 22,
                            alignment: .leading
                        )
                        BrandMetric(
                            title: LocalizedStringKey("duration_title"),
                            value: ride.duration.formattedAsTimer,
                            size: 22,
                            alignment: .leading
                        )
                        BrandMetric(
                            title: LocalizedStringKey("average_speed_title"),
                            value: RideFormatters.speed(kmh: ride.averageSpeed),
                            size: 18,
                            alignment: .leading
                        )
                        BrandMetric(
                            title: LocalizedStringKey("max_speed_title"),
                            value: RideFormatters.speed(kmh: ride.maxSpeed),
                            size: 18,
                            alignment: .leading
                        )
                        if ride.resolvedElevationGain > 0 {
                            BrandMetric(
                                title: LocalizedStringKey("elevation_title"),
                                value: RideFormatters.elevation(meters: ride.resolvedElevationGain),
                                size: 18,
                                alignment: .leading
                            )
                        }
                        if let bikeName {
                            BrandMetric(
                                title: LocalizedStringKey("garage_bike_name"),
                                value: bikeName,
                                size: 18,
                                alignment: .leading
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStringKey("start_date_title"))
                            .font(Brand.Font.micro)
                            .foregroundStyle(Brand.Color.muted)
                        Text(ride.startDate.formatted(date: .long, time: .shortened))
                            .font(Brand.Font.headline)
                            .foregroundStyle(Brand.Color.ink)
                    }
                    .padding(.top, 4)

                    RideLineColorEditor(ride: ride, ridesViewModel: ridesViewModel)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 16)

                let profile = ride.elevationProfile
                if profile.count > 1 {
                    BrandCard {
                        ElevationProfileView(samples: profile)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .brandScreen()
        .navigationTitle(LocalizedStringKey("ride_details"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
    }
}
