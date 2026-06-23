//
//  WidgetDataService.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 06.03.2025.
//

import Foundation
import WidgetKit

/// Writes ride summary data to the shared App Group so widgets can read it.
/// Call `sync(rides:)` after any change to the rides list.
final class WidgetDataService {
    static let shared = WidgetDataService()
    private init() {}

    /// Converts Ride models to widget entries, persists them, and asks WidgetKit to refresh.
    func sync(rides: [Ride]) {
        let entries = rides.map { RideWidgetEntry(startDate: $0.startDate, distanceKm: $0.distance / 1000) }
        RideWidgetEntry.save(entries)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
