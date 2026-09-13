import SwiftUI
import UIKit

/// Trail Dawn — visual identity for MyBikeTracker.
enum Brand {
    static let name = "MyBikeTracker"

    enum Color {
        static let canvas = AdaptiveColor(light: 0xF3EEE6, dark: 0x0A100E).color
        static let surface = AdaptiveColor(light: 0xFFFCF7, dark: 0x141C19).color
        static let surfaceMuted = AdaptiveColor(light: 0xE8E2D6, dark: 0x1C2723).color
        static let ink = AdaptiveColor(light: 0x13201B, dark: 0xF4F0E8).color
        static let muted = AdaptiveColor(light: 0x5E6B66, dark: 0x9AABA4).color
        static let trail = AdaptiveColor(light: 0x1B7A6E, dark: 0x4AD1C3).color
        static let trailDeep = AdaptiveColor(light: 0x0F4F47, dark: 0x1B7A6E).color
        static let ember = AdaptiveColor(light: 0xE85A32, dark: 0xFF7A4D).color
        static let meadow = AdaptiveColor(light: 0x2F8F5B, dark: 0x5FD08A).color
        static let amber = AdaptiveColor(light: 0xC9841D, dark: 0xE8B04A).color
        static let danger = AdaptiveColor(light: 0xD64545, dark: 0xFF6B6B).color
        static let live = meadow
        static let paused = amber

        static let glowEmber = ember.opacity(0.38)
        static let glowTrail = trail.opacity(0.28)
        static let hairline = ink.opacity(0.08)
    }

    enum Space {
        static let xxs: CGFloat = 4
        static let xs: CGFloat = 8
        static let sm: CGFloat = 12
        static let md: CGFloat = 16
        static let lg: CGFloat = 20
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let sm: CGFloat = 12
        static let md: CGFloat = 18
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Font {
        static func display(_ size: CGFloat, weight: SwiftUI.Font.Weight = .bold) -> SwiftUI.Font {
            let style: SwiftUI.Font.TextStyle
            switch size {
            case 28...: style = .title
            case 22...: style = .title2
            default: style = .title3
            }
            return .system(style, design: .rounded).weight(weight)
        }

        static func metric(_ size: CGFloat = 22) -> SwiftUI.Font {
            let style: SwiftUI.Font.TextStyle = size >= 22 ? .title2 : .title3
            return .system(style, design: .rounded).weight(.bold).monospacedDigit()
        }

        static let title = SwiftUI.Font.system(.title2, design: .rounded).weight(.bold)
        static let headline = SwiftUI.Font.system(.headline, design: .rounded).weight(.semibold)
        static let body = SwiftUI.Font.body
        static let caption = SwiftUI.Font.system(.caption, design: .rounded).weight(.semibold)
        static let micro = SwiftUI.Font.system(.caption2, design: .rounded).weight(.medium)
    }

    enum Motion {
        static let appear = Animation.spring(response: 0.48, dampingFraction: 0.82)
        static let snappy = Animation.spring(response: 0.32, dampingFraction: 0.78)
        static let soft = Animation.spring(response: 0.55, dampingFraction: 0.9)
        static let ring = Animation.spring(response: 0.92, dampingFraction: 0.86)

        static func appear(reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: 0.18) : appear
        }

        static func snappy(reduceMotion: Bool) -> Animation {
            reduceMotion ? .easeOut(duration: 0.15) : snappy
        }
    }

    enum UIColorToken {
        static let trail = AdaptiveColor(light: 0x1B7A6E, dark: 0x4AD1C3).uiColor
        static let ember = AdaptiveColor(light: 0xE85A32, dark: 0xFF7A4D).uiColor
        static let canvas = AdaptiveColor(light: 0xF3EEE6, dark: 0x0A100E).uiColor
    }

    enum Appearance {
        static func configure() {
            UITabBar.appearance().isHidden = true

            let nav = UINavigationBarAppearance()
            nav.configureWithTransparentBackground()
            nav.titleTextAttributes = [
                .foregroundColor: UIColor.label,
                .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
            ]
            nav.largeTitleTextAttributes = [
                .foregroundColor: UIColor.label,
                .font: UIFont.systemFont(ofSize: 34, weight: .bold)
            ]
            UINavigationBar.appearance().standardAppearance = nav
            UINavigationBar.appearance().scrollEdgeAppearance = nav
            UINavigationBar.appearance().compactAppearance = nav
            UINavigationBar.appearance().tintColor = UIColorToken.trail

            UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self]).tintColor = UIColorToken.trail
        }
    }
}

struct AdaptiveColor {
    let light: UInt32
    let dark: UInt32

    var uiColor: UIColor {
        UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        }
    }

    var color: Color { Color(uiColor: uiColor) }
}

extension UIColor {
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }
}

enum BrandHaptics {
    static func select() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}
