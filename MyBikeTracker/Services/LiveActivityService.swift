//
//  LiveActivityService.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 06.03.2025.
//

import ActivityKit
import Foundation

/// Manages the lifecycle of a Live Activity (Lock Screen + Dynamic Island) during a bike ride.
@MainActor
final class LiveActivityService {

    // MARK: - State

    private var activity: Activity<BikeTrackerAttributes>?

    // MARK: - Start

    /// Starts a new Live Activity when a ride begins.
    func start(startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }   // guard against duplicates

        let attributes = BikeTrackerAttributes(startDate: startDate)
        let initialState = BikeTrackerAttributes.ContentState(
            elapsedSeconds: 0,
            speed: 0,
            distance: 0,
            isPaused: false
        )

        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            activity = try Activity<BikeTrackerAttributes>.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("LiveActivity start error: \(error.localizedDescription)")
        }
    }

    // MARK: - Update

    /// Pushes updated metrics to the Live Activity (called every second by the timer).
    func update(elapsed: TimeInterval, speed: Double, distance: Double, isPaused: Bool) async {
        guard let activity else { return }

        let newState = BikeTrackerAttributes.ContentState(
            elapsedSeconds: Int(elapsed),
            speed: speed,
            distance: distance,
            isPaused: isPaused
        )

        let content = ActivityContent(state: newState, staleDate: nil)
        await activity.update(content)
    }

    // MARK: - Stop

    /// Ends the Live Activity when the ride finishes.
    func stop(elapsed: TimeInterval, speed: Double, distance: Double) async {
        guard let activity else { return }

        let finalState = BikeTrackerAttributes.ContentState(
            elapsedSeconds: Int(elapsed),
            speed: speed,
            distance: distance,
            isPaused: false
        )

        let content = ActivityContent(state: finalState, staleDate: nil)
        await activity.end(content, dismissalPolicy: .after(.now + 5))
        self.activity = nil
    }
}
