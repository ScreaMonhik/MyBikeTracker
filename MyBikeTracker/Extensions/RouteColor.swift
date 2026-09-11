//
//  RouteColor.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import SwiftUI
import UIKit

/// Stored route-line colors: `#RRGGBB`, plus the legacy 8 named presets.
enum RouteLineColor {
    static let defaultTrackerHex = "#FF3B30"
    static let defaultHistoryHex = "#007AFF"

    static func color(from stored: String, fallbackHex: String = defaultHistoryHex) -> Color {
        Color(uiColor: uiColor(from: stored, fallbackHex: fallbackHex))
    }

    static func uiColor(from stored: String, fallbackHex: String = defaultHistoryHex) -> UIColor {
        if let parsed = parse(stored) { return parsed }
        if let parsed = parse(fallbackHex) { return parsed }
        return .systemBlue
    }

    static func hexString(from color: Color) -> String {
        hexString(from: UIColor(color))
    }

    static func hexString(from uiColor: UIColor) -> String {
        let space = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let converted = uiColor.cgColor.converted(to: space, intent: .defaultIntent, options: nil) else {
            return defaultHistoryHex
        }
        let components = converted.components ?? [0, 0, 0]
        let red = components[0]
        let green = components.count > 1 ? components[1] : components[0]
        let blue = components.count > 2 ? components[2] : components[0]
        return String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
    }

    private static func parse(_ stored: String) -> UIColor? {
        let trimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if let legacy = legacyPalette[trimmed.lowercased()] {
            return legacy
        }
        return parseHex(trimmed)
    }

    private static func parseHex(_ raw: String) -> UIColor? {
        var hex = raw
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 || hex.count == 8,
              let value = UInt64(hex, radix: 16) else { return nil }

        let hasAlpha = hex.count == 8
        let shift = hasAlpha ? 8 : 0
        let red = CGFloat((value >> (16 + shift)) & 0xFF) / 255
        let green = CGFloat((value >> (8 + shift)) & 0xFF) / 255
        let blue = CGFloat((value >> shift) & 0xFF) / 255
        return UIColor(red: red, green: green, blue: blue, alpha: 1)
    }

    private static func channel(_ value: CGFloat) -> Int {
        Int((max(0, min(1, value)) * 255).rounded())
    }

    private static let legacyPalette: [String: UIColor] = [
        "red": .systemRed,
        "blue": .systemBlue,
        "green": .systemGreen,
        "orange": .systemOrange,
        "purple": .systemPurple,
        "cyan": .systemCyan,
        "yellow": .systemYellow,
        "pink": .systemPink
    ]
}

extension Ride {
    func resolvedLineUIColor(defaultHex: String) -> UIColor {
        RouteLineColor.uiColor(from: lineColorHex ?? defaultHex, fallbackHex: defaultHex)
    }

    func resolvedLineColor(defaultHex: String) -> Color {
        Color(uiColor: resolvedLineUIColor(defaultHex: defaultHex))
    }
}

// MARK: - AppStorage keys

extension String {
    static let trackerRouteColorKey = "tracker_route_color"
    static let historyRouteColorKey = "history_route_color"
}
