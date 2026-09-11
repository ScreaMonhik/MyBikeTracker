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
    private var startTask: Task<Void, Never>?

    init() {
        // Crash / force-quit leaves the Dynamic Island up because we only
        // kept an in-memory handle. Drop leftovers as soon as the app launches.
        Task { await endAll(content: nil) }
    }

    // MARK: - Start

    /// Starts a new Live Activity when a ride begins.
    func start(startDate: Date) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        startTask?.cancel()
        startTask = Task {
            await endAll(content: nil)
            guard !Task.isCancelled else { return }

            let attributes = BikeTrackerAttributes(startDate: startDate)
            let initialState = BikeTrackerAttributes.ContentState(
                elapsedSeconds: 0,
                speed: 0,
                distance: 0,
                isPaused: false
            )

            do {
                activity = try Activity<BikeTrackerAttributes>.request(
                    attributes: attributes,
                    content: ActivityContent(state: initialState, staleDate: nil),
                    pushType: nil
                )
            } catch {
                print("LiveActivity start error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Update

    /// Pushes updated metrics to the Live Activity (called every second by the timer).
    func update(elapsed: TimeInterval, speed: Double, distance: Double, isPaused: Bool) async {
        let newState = BikeTrackerAttributes.ContentState(
            elapsedSeconds: Int(elapsed),
            speed: speed,
            distance: distance,
            isPaused: isPaused
        )
        let content = ActivityContent(state: newState, staleDate: nil)

        let targets = currentActivities()
        guard !targets.isEmpty else { return }
        if activity == nil {
            activity = targets.first
        }
        for item in targets {
            await item.update(content)
        }
    }

    // MARK: - Stop

    /// Ends every Live Activity for this ride type immediately.
    func stop(elapsed: TimeInterval, speed: Double, distance: Double) async {
        startTask?.cancel()
        startTask = nil

        let finalState = BikeTrackerAttributes.ContentState(
            elapsedSeconds: Int(elapsed),
            speed: speed,
            distance: distance,
            isPaused: false
        )
        await endAll(content: ActivityContent(state: finalState, staleDate: nil))
    }

    // MARK: - Private

    private func currentActivities() -> [Activity<BikeTrackerAttributes>] {
        Array(Activity<BikeTrackerAttributes>.activities)
    }

    private func endAll(content: ActivityContent<BikeTrackerAttributes.ContentState>?) async {
        let targets = currentActivities()
        for item in targets {
            await item.end(content, dismissalPolicy: .immediate)
        }
        activity = nil
    }
}
