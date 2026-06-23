//
//  RouteColor.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import SwiftUI

/// Набор доступных цветов линии маршрута на карте.
/// Хранится как String в AppStorage.
enum RouteColor: String, CaseIterable, Identifiable {
    case red    = "red"
    case blue   = "blue"
    case green  = "green"
    case orange = "orange"
    case purple = "purple"
    case cyan   = "cyan"
    case yellow = "yellow"
    case pink   = "pink"

    var id: String { rawValue }

    var label: LocalizedStringKey {
        switch self {
        case .red:    return "color_red"
        case .blue:   return "color_blue"
        case .green:  return "color_green"
        case .orange: return "color_orange"
        case .purple: return "color_purple"
        case .cyan:   return "color_cyan"
        case .yellow: return "color_yellow"
        case .pink:   return "color_pink"
        }
    }

    var color: Color {
        switch self {
        case .red:    return .red
        case .blue:   return .blue
        case .green:  return .green
        case .orange: return .orange
        case .purple: return .purple
        case .cyan:   return .cyan
        case .yellow: return .yellow
        case .pink:   return .pink
        }
    }

    var uiColor: UIColor {
        switch self {
        case .red:    return .systemRed
        case .blue:   return .systemBlue
        case .green:  return .systemGreen
        case .orange: return .systemOrange
        case .purple: return .systemPurple
        case .cyan:   return .systemCyan
        case .yellow: return .systemYellow
        case .pink:   return .systemPink
        }
    }
}

// MARK: - AppStorage keys

extension String {
    static let trackerRouteColorKey = "tracker_route_color"
    static let historyRouteColorKey = "history_route_color"
}
