import MapKit
import SwiftUI

/// Per-bike slow / medium / fast thresholds used to color a speed heatmap.
struct PaceScale: Hashable, Sendable {
    var slowMaxKmh: Double
    var mediumMaxKmh: Double

    /// Matches the original teal → ember stops (12 / 28 km/h).
    static let `default` = PaceScale(slowMaxKmh: 12, mediumMaxKmh: 28)

    enum Band: Int, CaseIterable, Hashable {
        case slow, medium, fast
    }

    var sanitized: PaceScale {
        let fallback = PaceScale.default
        var slow = slowMaxKmh > 0 ? slowMaxKmh : fallback.slowMaxKmh
        var medium = mediumMaxKmh > 0 ? mediumMaxKmh : fallback.mediumMaxKmh
        slow = min(max(slow, 5), 45)
        medium = min(max(medium, slow + 2), 55)
        return PaceScale(slowMaxKmh: slow, mediumMaxKmh: medium)
    }

    func band(forKmh kmh: Double) -> Band {
        let scale = sanitized
        if kmh < scale.slowMaxKmh { return .slow }
        if kmh < scale.mediumMaxKmh { return .medium }
        return .fast
    }

    /// Continuous heatmap stops stretched to this bike's pace levels.
    var colorStops: [(kmh: Double, hex: UInt32)] {
        let scale = sanitized
        let mid = (scale.slowMaxKmh + scale.mediumMaxKmh) / 2
        let fastTop = scale.mediumMaxKmh + max(8, (scale.mediumMaxKmh - scale.slowMaxKmh) * 1.2)
        return [
            (0, 0x1B7A6E),
            (scale.slowMaxKmh, 0x2F8F5B),
            (mid, 0xC9841D),
            (scale.mediumMaxKmh, 0xE85A32),
            (fastTop, 0xD64545)
        ]
    }

    var scaleMaxKmh: Double { colorStops.last?.kmh ?? 40 }

    func discreteColor(for band: Band) -> Color {
        switch band {
        case .slow: Color(uiColor: UIColor(rgb: 0x1B7A6E))
        case .medium: Color(uiColor: UIColor(rgb: 0xC9841D))
        case .fast: Color(uiColor: UIColor(rgb: 0xE85A32))
        }
    }
}

/// Distance-weighted slow / medium / fast shares for one ride.
enum RidePaceShare {
    static func fractions(slices: [SpeedColoredSlice], scale: PaceScale) -> [(PaceScale.Band, Double)] {
        var distances: [PaceScale.Band: Double] = [:]
        for slice in slices {
            let length = RideTrackGeometry.polylineDistance(slice.coordinates)
            guard length > 0 else { continue }
            distances[scale.band(forKmh: slice.speedKmh), default: 0] += length
        }
        let total = PaceScale.Band.allCases.reduce(0) { $0 + (distances[$1] ?? 0) }
        guard total > 0 else { return [(.slow, 1)] }
        return PaceScale.Band.allCases.map { band in
            (band, (distances[band] ?? 0) / total)
        }
    }
}

/// Newest ride is a heatmap unless the user selected another line.
enum MapRideHeatmap {
    static func isActive(rideID: UUID, newestRideID: UUID?, selectedRideID: UUID?) -> Bool {
        if let selectedRideID { return rideID == selectedRideID }
        return rideID == newestRideID
    }
}

/// One same-speed stretch of a ride line.
struct SpeedColoredSlice: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let speedKmh: Double

    func color(scale: PaceScale = .default) -> Color {
        SpeedHeatmap.color(forKmh: speedKmh, scale: scale)
    }
}

/// Brand heatmap: teal is slow, ember / red is fast.
enum SpeedHeatmap {
    static let bandWidthKmh = 4.0
    static let maxBand = 10

    static func fillFraction(forKmh kmh: Double, scale: PaceScale = .default) -> Double {
        let top = max(scale.scaleMaxKmh, 1)
        return min(1, max(0, kmh / top))
    }

    static func band(forKmh kmh: Double) -> Int {
        min(maxBand, max(0, Int(kmh / bandWidthKmh)))
    }

    static func color(forKmh kmh: Double, scale: PaceScale = .default) -> Color {
        Color(uiColor: uiColor(forKmh: kmh, scale: scale))
    }

    static func uiColor(forKmh kmh: Double, scale: PaceScale = .default) -> UIColor {
        let stops = scale.colorStops
        let kmh = max(0, kmh)
        if kmh <= stops[0].kmh { return UIColor(rgb: stops[0].hex) }
        if let last = stops.last, kmh >= last.kmh { return UIColor(rgb: last.hex) }

        for index in 1..<stops.count {
            let next = stops[index]
            guard kmh <= next.kmh else { continue }
            let previous = stops[index - 1]
            let span = next.kmh - previous.kmh
            let t = span > 0 ? (kmh - previous.kmh) / span : 0
            return mix(UIColor(rgb: previous.hex), UIColor(rgb: next.hex), amount: t)
        }
        return UIColor(rgb: stops[0].hex)
    }

    static func legendColors(scale: PaceScale = .default) -> [Color] {
        scale.colorStops.map { color(forKmh: $0.kmh, scale: scale) }
    }

    static var legendColors: [Color] {
        legendColors(scale: .default)
    }

    static var legendStopsKmh: [Double] {
        PaceScale.default.colorStops.map(\.kmh)
    }

    static var scaleMaxKmh: Double { PaceScale.default.scaleMaxKmh }

    private static func mix(_ from: UIColor, _ to: UIColor, amount: Double) -> UIColor {
        var fr: CGFloat = 0, fg: CGFloat = 0, fb: CGFloat = 0, fa: CGFloat = 0
        var tr: CGFloat = 0, tg: CGFloat = 0, tb: CGFloat = 0, ta: CGFloat = 0
        from.getRed(&fr, green: &fg, blue: &fb, alpha: &fa)
        to.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        let t = CGFloat(min(1, max(0, amount)))
        return UIColor(
            red: fr + (tr - fr) * t,
            green: fg + (tg - fg) * t,
            blue: fb + (tb - fb) * t,
            alpha: 1
        )
    }
}

@MainActor
func speedTrackMapContent(
    slices: [SpeedColoredSlice],
    scale: PaceScale = .default,
    lineWidth: CGFloat = 4.5,
    idPrefix: String = ""
) -> some MapContent {
    let tagged = slices.map { slice in
        SpeedColoredSlice(
            id: idPrefix.isEmpty ? slice.id : "\(idPrefix)-\(slice.id)",
            coordinates: slice.coordinates,
            speedKmh: slice.speedKmh
        )
    }
    return speedTrackPolylines(slices: tagged, scale: scale, lineWidth: lineWidth)
}

@MainActor
@MapContentBuilder
private func speedTrackPolylines(
    slices: [SpeedColoredSlice],
    scale: PaceScale,
    lineWidth: CGFloat
) -> some MapContent {
    ForEach(slices) { slice in
        if slice.coordinates.count > 1 {
            MapPolyline(coordinates: slice.coordinates)
                .stroke(
                    Color.white.opacity(0.9),
                    style: StrokeStyle(lineWidth: lineWidth + 2.5, lineCap: .round, lineJoin: .round)
                )
            MapPolyline(coordinates: slice.coordinates)
                .stroke(
                    slice.color(scale: scale),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
        }
    }
}
