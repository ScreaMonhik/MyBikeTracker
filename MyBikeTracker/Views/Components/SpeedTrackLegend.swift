import SwiftUI

/// Compact slow → fast key. During a live ride the bar fills with current speed.
struct SpeedTrackLegend: View {
    var currentSpeedKmh: Double? = nil
    var scale: PaceScale = .default

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let barWidth: CGFloat = 10
    private let barHeight: CGFloat = 80
    private let knobSize: CGFloat = 14

    private var isLive: Bool { currentSpeedKmh != nil }

    private var fillFraction: CGFloat {
        guard let currentSpeedKmh else { return 1 }
        return CGFloat(SpeedHeatmap.fillFraction(forKmh: currentSpeedKmh, scale: scale))
    }

    private var visibleFill: CGFloat {
        guard isLive else { return 1 }
        return max(fillFraction, 0.05)
    }

    private var gradient: LinearGradient {
        LinearGradient(
            colors: SpeedHeatmap.legendColors(scale: scale).reversed(),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    var body: some View {
        VStack(spacing: 6) {
            Text(LocalizedStringKey("speed_legend_fast"))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.ink)

            if isLive {
                liveThermometer
            } else {
                staticBar
            }

            Text(LocalizedStringKey("speed_legend_slow"))
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.ink)
        }
        .padding(.horizontal, isLive ? 12 : 10)
        .padding(.vertical, 10)
        .liquidGlass(in: RoundedRectangle(cornerRadius: Brand.Radius.sm, style: .continuous))
        .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LocalizedStringKey("speed_legend_accessibility"))
        .accessibilityValue(currentSpeedKmh.map { RideFormatters.speed(kmh: $0) } ?? "")
        .accessibilityAddTraits(isLive ? .updatesFrequently : [])
    }

    private var staticBar: some View {
        gradient
            .frame(width: 8, height: 72)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
            }
    }

    private var liveThermometer: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(Brand.Color.ink.opacity(0.08))

            gradient
                .opacity(0.22)

            gradient
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: barHeight * visibleFill)
                }

            Capsule()
                .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
        }
        .frame(width: barWidth, height: barHeight)
        .clipShape(Capsule())
        .overlay(alignment: .bottom) {
            Circle()
                    .fill(SpeedHeatmap.color(forKmh: currentSpeedKmh ?? 0, scale: scale))
                    .frame(width: knobSize, height: knobSize)
                    .overlay {
                        Circle()
                            .strokeBorder(Color.white, lineWidth: 2)
                    }
                    .shadow(color: SpeedHeatmap.color(forKmh: currentSpeedKmh ?? 0, scale: scale).opacity(0.45), radius: 4)
                .offset(y: knobOffset)
                .accessibilityHidden(true)
        }
        .frame(width: max(barWidth, knobSize), height: barHeight)
        .animation(Brand.Motion.snappy(reduceMotion: reduceMotion), value: visibleFill)
    }

    /// Places the knob on the fill tip, slightly overlapping the capsule.
    private var knobOffset: CGFloat {
        let travel = barHeight - knobSize
        return -(travel * fillFraction)
    }
}

/// Horizontal bar whose color widths match this ride's slow / medium / fast distance.
struct RidePaceDistributionLegend: View {
    let slices: [SpeedColoredSlice]
    var scale: PaceScale = .default

    private var shares: [(PaceScale.Band, Double)] {
        RidePaceShare.fractions(slices: slices, scale: scale)
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey("speed_legend_slow"))
            GeometryReader { geo in
                HStack(spacing: 0) {
                    ForEach(shares, id: \.0) { band, fraction in
                        if fraction > 0.004 {
                            scale.discreteColor(for: band)
                                .frame(width: geo.size.width * fraction)
                        }
                    }
                }
            }
            .frame(height: 6)
            .clipShape(Capsule())
            Text(LocalizedStringKey("speed_legend_fast"))
        }
        .font(Brand.Font.micro)
        .foregroundStyle(Brand.Color.muted)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(LocalizedStringKey("ride_pace_legend_accessibility"))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        let parts = shares.compactMap { band, fraction -> String? in
            guard fraction > 0.02 else { return nil }
            let percent = Int((fraction * 100).rounded())
            let key: String
            switch band {
            case .slow: key = "speed_legend_slow"
            case .medium: key = "speed_legend_medium"
            case .fast: key = "speed_legend_fast"
            }
            return "\(percent)% \(NSLocalizedString(key, comment: ""))"
        }
        return Text(parts.joined(separator: ", "))
    }
}
