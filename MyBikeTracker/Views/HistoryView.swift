//
//  HistoryView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var ridesViewModel: RidesViewModel
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @State private var showDeleteConfirmation = false
    @State private var indexSetToDelete: IndexSet?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeeklyGoalCard(
                        thisWeek: ridesViewModel.thisWeek,
                        lastWeek: ridesViewModel.lastWeek
                    )
                }

                if !ridesViewModel.chainDueBikes.isEmpty {
                    Section {
                        ForEach(ridesViewModel.chainDueBikes, id: \.id) { bike in
                            Label {
                                Text(String(
                                    format: NSLocalizedString("garage_chain_due_named", comment: ""),
                                    bike.name
                                ))
                            } icon: {
                                Image(systemName: "wrench.and.screwdriver")
                            }
                            .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    ForEach(ridesViewModel.rides) { ride in
                        NavigationLink {
                            RideDetailView(
                                ridesViewModel: ridesViewModel,
                                ride: ride,
                                bikeName: ridesViewModel.bike(for: ride)?.name
                            )
                        } label: {
                            RideRowView(ride: ride)
                        }
                    }
                    .onDelete { offsets in
                        indexSetToDelete = offsets
                        showDeleteConfirmation = true
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("history_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RideCalendarView(ridesViewModel: ridesViewModel)
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3)
                    }
                    .accessibilityLabel(LocalizedStringKey("calendar_title"))
                }
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
