//
//  HistoryView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @State private var showDeleteConfirmation = false
    @State private var indexSetToDelete: IndexSet?
    @State private var showCalendar = false

    var body: some View {
        NavigationView {
            List {
                ForEach(ridesViewModel.rides) { ride in
                    NavigationLink(destination: RideDetailView(ride: ride)) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(LocalizedStringKey("ride_from"))
                                Text(ride.startDate.formatted(date: .abbreviated, time: .shortened))
                                    .fontWeight(.semibold)
                            }
                            HStack {
                                Text(LocalizedStringKey("duration_title"))
                                Text(ride.duration.formattedAsTimer)
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text(LocalizedStringKey("distance_title"))
                                Text(String(format: "%.2f %@", ride.distance / 1000, NSLocalizedString("distance_unit", comment: "")))
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text(LocalizedStringKey("average_speed_title"))
                                Text(String(format: "%.1f %@", ride.averageSpeed, NSLocalizedString("speed_unit", comment: "")))
                                    .foregroundColor(.secondary)
                            }
                            HStack {
                                Text(LocalizedStringKey("max_speed_title"))
                                Text(String(format: "%.1f %@", ride.maxSpeed, NSLocalizedString("speed_unit", comment: "")))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    indexSetToDelete = offsets
                    showDeleteConfirmation = true
                }
            }
            .navigationTitle(LocalizedStringKey("history_title"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                RideCalendarView(rides: ridesViewModel.rides)
            }
            .alert(LocalizedStringKey("delete_confirmation"), isPresented: $showDeleteConfirmation) {
                Button(LocalizedStringKey("yes"), role: .destructive) {
                    if let offsets = indexSetToDelete {
                        ridesViewModel.deleteRide(at: offsets)
                    }
                }
                Button(LocalizedStringKey("no"), role: .cancel) {}
            } message: {
                Text(LocalizedStringKey("delete_confirmation_message"))
            }
        }
    }
}
