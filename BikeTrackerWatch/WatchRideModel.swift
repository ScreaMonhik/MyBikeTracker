import Foundation
import WatchConnectivity

@MainActor
final class WatchRideModel: NSObject, ObservableObject {
    @Published var isTracking = false
    @Published var isPaused = false
    @Published var elapsed: TimeInterval = 0
    @Published var speed: Double = 0
    @Published var distance: Double = 0
    @Published var isReachable = false

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        refreshReachability()
    }

    func start() { send(.start) }
    func togglePause() { send(isPaused ? .resume : .pause) }
    func stop() { send(.stop) }

    private func send(_ command: RideRemoteCommand) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        let payload = [RideRemoteKey.command: command.rawValue]
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            session.transferUserInfo(payload)
        }
    }

    private func apply(_ message: [String: Any]) {
        if let tracking = message[RideRemoteKey.tracking] as? Bool {
            isTracking = tracking
        }
        if let paused = message[RideRemoteKey.paused] as? Bool {
            isPaused = paused
        }
        if let elapsed = message[RideRemoteKey.elapsed] as? TimeInterval {
            self.elapsed = elapsed
        } else if let elapsed = message[RideRemoteKey.elapsed] as? Double {
            self.elapsed = elapsed
        }
        if let speed = message[RideRemoteKey.speed] as? Double {
            self.speed = speed
        }
        if let distance = message[RideRemoteKey.distance] as? Double {
            self.distance = distance
        }
    }

    private func refreshReachability() {
        guard WCSession.isSupported() else { return }
        isReachable = WCSession.default.isReachable
    }
}

extension WatchRideModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            refreshReachability()
            apply(session.receivedApplicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            apply(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            apply(message)
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            refreshReachability()
        }
    }
}
