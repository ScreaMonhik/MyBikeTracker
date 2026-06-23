//
//  RideWidgetEntry.swift
//  MyBikeTracker
//
//  ⚠️ Add this file to BOTH targets: MyBikeTracker + BikeTrackerWidget
//

import Foundation

/// Minimal ride summary stored in App Group UserDefaults for widget consumption.
struct RideWidgetEntry: Codable {
    var startDate: Date
    var distanceKm: Double
}

// MARK: - Shared read/write helpers

extension RideWidgetEntry {

    /// Saves the given rides to shared App Group UserDefaults.
    static func save(_ rides: [RideWidgetEntry]) {
        guard let defaults = UserDefaults(suiteName: AppGroup.id) else { return }
        let data = try? JSONEncoder().encode(rides)
        defaults.set(data, forKey: AppGroup.widgetRidesKey)
    }

    /// Loads rides from shared App Group UserDefaults.
    static func load() -> [RideWidgetEntry] {
        guard let defaults = UserDefaults(suiteName: AppGroup.id),
              let data = defaults.data(forKey: AppGroup.widgetRidesKey) else { return [] }
        return (try? JSONDecoder().decode([RideWidgetEntry].self, from: data)) ?? []
    }

    // MARK: - Convenience computed stats

    static func yearlyDistanceKm(from entries: [RideWidgetEntry]) -> Double {
        let year = Calendar.current.component(.year, from: Date())
        return entries
            .filter { Calendar.current.component(.year, from: $0.startDate) == year }
            .reduce(0) { $0 + $1.distanceKm }
    }

    static func rideDays(from entries: [RideWidgetEntry]) -> Set<DateComponents> {
        var result = Set<DateComponents>()
        for entry in entries {
            let comps = Calendar.current.dateComponents([.year, .month, .day], from: entry.startDate)
            result.insert(comps)
        }
        return result
    }
}
