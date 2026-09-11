import Foundation

enum PreferenceKey {
    static let distanceUnitSystem = "distance_unit_system"
    static let weeklyGoalKilometers = "weekly_goal_kilometers"
    static let autoPauseSpeedKmh = "autopause_speed_kmh"
    static let autoPauseDelaySeconds = "autopause_delay_seconds"
    static let selectedBikeId = "selected_bike_id"
    static let wheelCircumferenceMm = "wheel_circumference_mm"
    static let healthKitEnabled = "healthkit_enabled"
    static let lastHeartRateSensorId = "last_hr_sensor_id"
    static let lastCadenceSensorId = "last_csc_sensor_id"
}

extension String {
    static let distanceUnitSystemKey = PreferenceKey.distanceUnitSystem
    static let weeklyGoalKilometersKey = PreferenceKey.weeklyGoalKilometers
    static let autoPauseSpeedKmhKey = PreferenceKey.autoPauseSpeedKmh
    static let autoPauseDelaySecondsKey = PreferenceKey.autoPauseDelaySeconds
    static let selectedBikeIdKey = PreferenceKey.selectedBikeId
}
