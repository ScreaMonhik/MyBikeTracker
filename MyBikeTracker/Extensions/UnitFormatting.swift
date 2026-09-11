import Foundation
import WidgetKit

enum DistanceUnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
}

enum UnitPreferences {
    static var current: DistanceUnitSystem {
        let raw = sharedDefaults.string(forKey: PreferenceKey.distanceUnitSystem)
            ?? UserDefaults.standard.string(forKey: PreferenceKey.distanceUnitSystem)
        return DistanceUnitSystem(rawValue: raw ?? "") ?? .metric
    }

    static func set(_ system: DistanceUnitSystem) {
        UserDefaults.standard.set(system.rawValue, forKey: PreferenceKey.distanceUnitSystem)
        sharedDefaults.set(system.rawValue, forKey: PreferenceKey.distanceUnitSystem)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: AppGroup.id) ?? .standard
    }
}

enum RideFormatters {
    static let metersPerMile = 1609.344
    static let kmhToMph = 0.621371192
    static let metersPerFoot = 0.3048

    static func distance(meters: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        String(format: "%@ %@", distanceValue(meters: meters, system: system), distanceUnitLabel(system: system))
    }

    static func distanceValue(meters: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return String(format: "%.2f", meters / 1000)
        case .imperial: return String(format: "%.2f", meters / metersPerMile)
        }
    }

    static func distanceUnitLabel(system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return localized("distance_unit", fallback: "km")
        case .imperial: return localized("distance_unit_mi", fallback: "mi")
        }
    }

    static func yearlyDistanceValue(kilometers: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return String(format: "%.1f", kilometers)
        case .imperial: return String(format: "%.1f", kilometers * kmhToMph)
        }
    }

    static func speed(kmh: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        String(format: "%@ %@", speedValue(kmh: kmh, system: system), speedUnitLabel(system: system))
    }

    static func speedValue(kmh: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return String(format: "%.1f", kmh)
        case .imperial: return String(format: "%.1f", kmh * kmhToMph)
        }
    }

    static func speedUnitLabel(system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return localized("speed_unit", fallback: "km/h")
        case .imperial: return localized("speed_unit_mph", fallback: "mph")
        }
    }

    static func elevation(meters: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        String(format: "%@ %@", elevationValue(meters: meters, system: system), elevationUnitLabel(system: system))
    }

    static func elevationValue(meters: Double, system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return String(format: "%.0f", meters)
        case .imperial: return String(format: "%.0f", meters / metersPerFoot)
        }
    }

    static func elevationUnitLabel(system: DistanceUnitSystem = UnitPreferences.current) -> String {
        switch system {
        case .metric: return localized("elevation_unit_m", fallback: "m")
        case .imperial: return localized("elevation_unit_ft", fallback: "ft")
        }
    }

    static func weeklyGoalKilometers(fromDisplay display: Double, system: DistanceUnitSystem) -> Double {
        switch system {
        case .metric: return display
        case .imperial: return display * metersPerMile / 1000
        }
    }

    static func weeklyGoalDisplay(kilometers: Double, system: DistanceUnitSystem) -> Double {
        switch system {
        case .metric: return kilometers
        case .imperial: return kilometers * 1000 / metersPerMile
        }
    }

    private static func localized(_ key: String, fallback: String) -> String {
        let value = NSLocalizedString(key, comment: "")
        return value == key ? fallback : value
    }
}
