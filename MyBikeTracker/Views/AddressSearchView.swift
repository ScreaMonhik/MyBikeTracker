//
//  AddressSearchView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 23.07.2026.
//

import SwiftUI
import MapKit

struct AddressSearchView: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Top Search Header
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search destination...", text: $viewModel.searchQuery)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        if !viewModel.searchQuery.isEmpty {
                            Button(action: {
                                viewModel.searchQuery = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)

                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)

                Divider()

                // Results List
                if viewModel.searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 44))
                            .foregroundColor(.secondary)
                        Text("Search for places or addresses")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else {
                    List(viewModel.searchResults, id: \.self) { completion in
                        Button {
                            Task {
                                await viewModel.selectCompletion(completion)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(completion.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.immediately)
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                isSearchFocused = true
                if let region = viewModel.currentRegion {
                    viewModel.updateCompleterRegion(region)
                }
            }
            .onDisappear {
                viewModel.searchQuery = ""
                viewModel.searchResults = []
            }
        }
    }
}
