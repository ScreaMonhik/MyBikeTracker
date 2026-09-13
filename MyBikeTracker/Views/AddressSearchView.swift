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
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Brand.Color.muted)

                        TextField(LocalizedStringKey("search_placeholder"), text: $viewModel.searchQuery)
                            .focused($isSearchFocused)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        if !viewModel.searchQuery.isEmpty {
                            Button {
                                viewModel.searchQuery = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(Brand.Color.muted)
                            }
                        }
                    }
                    .padding(12)
                    .background(Brand.Color.surfaceMuted, in: Capsule())

                    Button(LocalizedStringKey("cancel_button")) {
                        dismiss()
                    }
                    .foregroundStyle(Brand.Color.trail)
                    .font(Brand.Font.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if viewModel.searchResults.isEmpty {
                    BrandEmptyState(
                        title: LocalizedStringKey("search_empty_title"),
                        message: LocalizedStringKey("search_empty_message"),
                        systemImage: "mappin.and.ellipse"
                    )
                    .padding(.top, 48)
                    Spacer()
                } else {
                    List(viewModel.searchResults, id: \.self) { completion in
                        Button {
                            Task {
                                await viewModel.selectCompletion(completion)
                                dismiss()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                    .font(Brand.Font.headline)
                                    .foregroundStyle(Brand.Color.ink)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(Brand.Font.micro)
                                        .foregroundStyle(Brand.Color.muted)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.immediately)
                    .scrollContentBackground(.hidden)
                }
            }
            .brandScreen()
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
