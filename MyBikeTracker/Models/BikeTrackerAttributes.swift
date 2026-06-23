//
//  BikeTrackerAttributes.swift
//  MyBikeTracker
//
//  ⚠️ This file must be added to BOTH the main app target AND the BikeTrackerWidget target.
//  In Xcode: select this file → File Inspector → tick both checkboxes under "Target Membership".
//

import ActivityKit
import Foundation

/// Describes a Live Activity for an active bike ride.
struct BikeTrackerAttributes: ActivityAttributes {

    // MARK: - Dynamic content (updated every second during the ride)

    public struct ContentState: Codable, Hashable {
        /// Elapsed ride time in seconds (excluding pauses).
        var elapsedSeconds: Int
        /// Current speed in km/h.
        var speed: Double
        /// Total ride distance in meters.
        var distance: Double
        /// Whether tracking is currently paused.
        var isPaused: Bool
    }

    // MARK: - Static content (set once when the activity starts)

    /// Date the ride started (used for Lock Screen elapsed time display).
    var startDate: Date
}
