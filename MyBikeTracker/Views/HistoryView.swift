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
    @State private var openedRideID: UUID?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            List {
                Section {
                    WeeklyGoalCard(
                        thisWeek: ridesViewModel.thisWeek,
                        lastWeek: ridesViewModel.lastWeek
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
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
                            .font(Brand.Font.caption)
                            .foregroundStyle(Brand.Color.amber)
                            .padding(.vertical, 4)
                            .brandListCard(fill: Brand.Color.amber.opacity(0.12))
                        }
                    }
                }

                Section {
                    if ridesViewModel.rides.isEmpty {
                        BrandEmptyState(
                            title: LocalizedStringKey("history_empty_title"),
                            message: LocalizedStringKey("history_empty_message")
                        )
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    } else {
                        ForEach(Array(ridesViewModel.rides.enumerated()), id: \.element.id) { index, ride in
                            Button {
                                openedRideID = ride.id
                            } label: {
                                RideRowView(ride: ride)
                            }
                            .buttonStyle(BrandCardButtonStyle())
                            .brandListCard()
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 10)
                            .animation(
                                Brand.Motion.appear(reduceMotion: reduceMotion).delay(Double(min(index, 8)) * 0.04),
                                value: appeared
                            )
                        }
                        .onDelete { offsets in
                            indexSetToDelete = offsets
                            showDeleteConfirmation = true
                        }
                    }
                } header: {
                    if !ridesViewModel.rides.isEmpty {
                        BrandSectionHeader(title: LocalizedStringKey("history_rides_section"))
                    }
                }
            }
            .listStyle(.plain)
            .brandListChrome()
            .brandListGutter()
            .navigationDestination(item: $openedRideID) { rideID in
                if let ride = ridesViewModel.rides.first(where: { $0.id == rideID }) {
                    RideDetailView(
                        ridesViewModel: ridesViewModel,
                        ride: ride,
                        bikeName: ridesViewModel.bike(for: ride)?.name
                    )
                }
            }
            .navigationTitle(LocalizedStringKey("history_title"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        RideCalendarView(ridesViewModel: ridesViewModel)
                    } label: {
                        Image(systemName: "calendar")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(Brand.Color.trail)
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
            .onAppear {
                appeared = true
            }
        }
    }
}
