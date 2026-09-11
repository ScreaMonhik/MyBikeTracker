import Foundation

enum RideRemoteKey {
    static let command = "command"
    static let tracking = "tracking"
    static let paused = "paused"
    static let elapsed = "elapsed"
    static let speed = "speed"
    static let distance = "distance"
}

enum RideRemoteCommand: String {
    case start
    case pause
    case resume
    case stop
}
