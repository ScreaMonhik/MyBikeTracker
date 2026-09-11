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

    private var sortedRides: [Ride] {
        rides.sorted { $0.startDate < $1.startDate }
    }

    private var totalDistance: Double {
        rides.reduce(0) { $0 + $1.distance }
    }

    private var totalDuration: TimeInterval {
        rides.reduce(0) { $0 + $1.duration }
    }

    var body: some View {
        Group {
            if rides.isEmpty {
                emptyState
            } else {
                List {
                    Section {
                        daySummary
                    }

                    Section {
                        ForEach(sortedRides) { ride in
                            NavigationLink {
                                RideDetailView(ride: ride)
                            } label: {
                                RideRowView(ride: ride, showsDate: false)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(date.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var daySummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("calendar_rides_count", comment: ""),
                Int64(rides.count)
            ))
            .font(.headline)

            HStack(spacing: 16) {
                labeledValue(
                    LocalizedStringKey("distance_title"),
                    String(format: "%.2f %@", totalDistance / 1000, NSLocalizedString("distance_unit", comment: ""))
                )
                labeledValue(
                    LocalizedStringKey("duration_title"),
                    totalDuration.formattedAsTimer
                )
            }
        }
        .padding(.vertical, 4)
    }

    private func labeledValue(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            LocalizedStringKey("calendar_no_rides_day"),
            systemImage: "bicycle",
            description: Text(LocalizedStringKey("calendar_no_rides_day_message"))
        )
    }
}
