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

    var body: some View {
        NavigationStack {
            List {
                ForEach(ridesViewModel.rides) { ride in
                    NavigationLink {
                        RideDetailView(ride: ride)
                    } label: {
                        RideRowView(ride: ride)
                    }
                }
                .onDelete { offsets in
                    indexSetToDelete = offsets
                    showDeleteConfirmation = true
                }
            }
            .navigationTitle(LocalizedStringKey("history_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RideCalendarView(rides: ridesViewModel.rides)
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
