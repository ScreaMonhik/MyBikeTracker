import Foundation
import WatchConnectivity

@MainActor
final class RideSessionBridge: NSObject {
    weak var mapViewModel: MapViewModel?
    private var lastContextSignature: String = ""

    func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    func pushState(
        tracking: Bool,
        paused: Bool,
        elapsed: TimeInterval,
        speed: Double,
        distance: Double
    ) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let payload: [String: Any] = [
            RideRemoteKey.tracking: tracking,
            RideRemoteKey.paused: paused,
            RideRemoteKey.elapsed: elapsed,
            RideRemoteKey.speed: speed,
            RideRemoteKey.distance: distance,
            RideRemoteKey.unitSystem: UnitPreferences.current.rawValue
        ]
        let signature = "\(tracking)|\(paused)|\(Int(elapsed))|\(Int(speed * 10))|\(Int(distance))"
        guard signature != lastContextSignature else { return }
        lastContextSignature = signature
        try? session.updateApplicationContext(payload)

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
    }

    private func handle(command raw: String) {
        guard let command = RideRemoteCommand(rawValue: raw), let mapViewModel else { return }
        switch command {
        case .start:
            if mapViewModel.startTime == nil {
                mapViewModel.startTracking()
            } else if mapViewModel.isPaused {
                mapViewModel.resumeTracking()
            }
        case .pause:
            mapViewModel.pauseTracking()
        case .resume:
            mapViewModel.resumeTracking()
        case .stop:
            mapViewModel.confirmStopTracking()
        case .discard:
            mapViewModel.discardRide()
        }
    }
}

extension RideSessionBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        guard let raw = message[RideRemoteKey.command] as? String else { return }
        Task { @MainActor [weak self] in
            self?.handle(command: raw)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let raw = userInfo[RideRemoteKey.command] as? String else { return }
        Task { @MainActor [weak self] in
            self?.handle(command: raw)
        }
    }
}
