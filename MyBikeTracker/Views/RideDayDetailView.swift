//
//  RideDayDetailView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 11.09.2026.
//

import SwiftUI

struct RideDayDetailView: View {
    let date: Date
    let rides: [Ride]
    @ObservedObject var ridesViewModel: RidesViewModel
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var openedRideID: UUID?

    private var sortedRides: [Ride] {
        rides.sorted { $0.startDate < $1.startDate }
    }

    private var totalDistance: Double {
        rides.reduce(0) { $0 + $1.distance }
    }

    private var totalDuration: TimeInterval {
        rides.reduce(0) { $0 + $1.duration }
    }

    private var totalElevation: Double {
        rides.reduce(0) { $0 + $1.resolvedElevationGain }
    }

    var body: some View {
        List {
            if !rides.isEmpty {
                Section {
                    daySummary
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            DayJournalSection(ridesViewModel: ridesViewModel, date: date)

            if rides.isEmpty {
                Section {
                    BrandEmptyState(
                        title: LocalizedStringKey("calendar_no_rides_day"),
                        message: LocalizedStringKey("calendar_no_rides_day_message")
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(sortedRides) { ride in
                        Button {
                            openedRideID = ride.id
                        } label: {
                            RideRowView(ride: ride, showsDate: false)
                        }
                        .buttonStyle(BrandCardButtonStyle())
                        .brandListCard()
                    }
                }
            }
        }
        .listStyle(.plain)
        .brandListChrome()
        .brandListGutter()
        .navigationDestination(item: $openedRideID) { rideID in
            if let ride = ridesViewModel.rides.first(where: { $0.id == rideID })
                ?? sortedRides.first(where: { $0.id == rideID }) {
                RideDetailView(
                    ridesViewModel: ridesViewModel,
                    ride: ride,
                    bikeName: ridesViewModel.bike(for: ride)?.name
                )
            }
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var daySummary: some View {
        BrandCard {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("calendar_rides_count", comment: ""),
                Int64(rides.count)
            ))
            .font(Brand.Font.headline)
            .foregroundStyle(Brand.Color.ink)

            HStack(spacing: 12) {
                BrandMetric(
                    title: LocalizedStringKey("distance_title"),
                    value: RideFormatters.distance(meters: totalDistance),
                    size: 18,
                    alignment: .leading
                )
                BrandMetric(
                    title: LocalizedStringKey("duration_title"),
                    value: totalDuration.formattedAsTimer,
                    size: 18,
                    alignment: .leading
                )
                if totalElevation > 0 {
                    BrandMetric(
                        title: LocalizedStringKey("elevation_title"),
                        value: RideFormatters.elevation(meters: totalElevation),
                        size: 18,
                        alignment: .leading
                    )
                }
            }
        }
    }
}
