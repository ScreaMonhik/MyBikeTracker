import MapKit
import SwiftUI

/// One same-speed stretch of a ride line.
struct SpeedColoredSlice: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let speedKmh: Double

    var color: Color { SpeedHeatmap.color(forKmh: speedKmh) }
}

/// Brand heatmap: teal is slow, ember / red is fast.
enum SpeedHeatmap {
    static let bandWidthKmh = 4.0
    static let maxBand = 10

    static let legendStopsKmh: [Double] = [0, 12, 20, 28, 40]

    static func band(forKmh kmh: Double) -> Int {
        min(maxBand, max(0, Int(kmh / bandWidthKmh)))
    }

    static func color(forKmh kmh: Double) -> Color {
        Color(uiColor: uiColor(forKmh: kmh))
    }

    static func uiColor(forKmh kmh: Double) -> UIColor {
        let stops: [(Double, UInt32)] = [
            (0, 0x1B7A6E),
            (12, 0x2F8F5B),
            (20, 0xC9841D),
            (28, 0xE85A32),
            (40, 0xD64545)
        ]
        let kmh = max(0, kmh)
        if kmh <= stops[0].0 { return UIColor(rgb: stops[0].1) }
        if let last = stops.last, kmh >= last.0 { return UIColor(rgb: last.1) }

        for index in 1..<stops.count {
            let next = stops[index]
            guard kmh <= next.0 else { continue }
            let previous = stops[index - 1]
            let span = next.0 - previous.0
            let t = span > 0 ? (kmh - previous.0) / span : 0
            return mix(UIColor(rgb: previous.1), UIColor(rgb: next.1), amount: t)
        }
        return UIColor(rgb: stops[0].1)
    }

    static var legendColors: [Color] {
        legendStopsKmh.map { color(forKmh: $0) }
    }

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
@MapContentBuilder
func speedTrackMapContent(
    slices: [SpeedColoredSlice],
    lineWidth: CGFloat = 4.5
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
                    slice.color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
                )
        }
    }
}
