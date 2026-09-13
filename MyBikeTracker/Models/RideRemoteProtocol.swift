import Foundation

enum RideRemoteKey {
    static let command = "command"
    static let tracking = "tracking"
    static let paused = "paused"
    static let elapsed = "elapsed"
    static let speed = "speed"
    static let distance = "distance"
    static let unitSystem = "unitSystem"
}

enum RideRemoteCommand: String {
    case start
    case pause
    case resume
    case stop
    case discard
}
