import CoreLocation
import SwiftUI

struct RideRowView: View {
    let ride: Ride
    var showsDate: Bool = true
    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex

    private var rideColor: Color {
        ride.resolvedLineColor(defaultHex: historyColorHex)
    }

    private var calendar: Calendar { .current }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            HStack(spacing: 0) {
                metric(
                    RideFormatters.distanceValue(meters: ride.distance),
                    RideFormatters.distanceUnitLabel()
                )
                metricDivider
                metric(
                    ride.duration.formattedAsCompactDuration,
                    NSLocalizedString("time_title", comment: "")
                )
                metricDivider
                metric(
                    RideFormatters.speedValue(kmh: ride.averageSpeed),
                    RideFormatters.speedUnitLabel()
                )
                if ride.resolvedElevationGain > 0 {
                    metricDivider
                    metric(
                        RideFormatters.elevationValue(meters: ride.resolvedElevationGain),
                        RideFormatters.elevationUnitLabel()
                    )
                }
            }

            if ride.displayCoordinates.count > 1 {
                RideRouteRibbon(segments: ride.displaySegments, color: rideColor)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .accessibilityElement(children: .combine)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if showsDate {
                dateTile
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(titleLine)
                    .font(Brand.Font.headline)
                    .foregroundStyle(Brand.Color.ink)
                    .lineLimit(1)
                if let subtitle = subtitleLine {
                    Text(subtitle)
                        .font(Brand.Font.micro)
                        .foregroundStyle(Brand.Color.muted)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if showsDate {
                Text(ride.startDate.formatted(date: .omitted, time: .shortened))
                    .font(Brand.Font.caption.monospacedDigit())
                    .foregroundStyle(Brand.Color.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Brand.Color.surfaceMuted, in: Capsule())
            }
        }
    }

    private var dateTile: some View {
        VStack(spacing: 1) {
            Text(ride.startDate, format: .dateTime.day())
                .font(Brand.Font.display(22))
            Text(ride.startDate.formatted(.dateTime.month(.abbreviated)))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .textCase(.uppercase)
        }
        .foregroundStyle(.white)
        .frame(width: 48, height: 48)
        .background(rideColor.gradient, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }

    private var titleLine: String {
        if !showsDate {
            return ride.startDate.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInToday(ride.startDate) {
            return NSLocalizedString("ride_when_today", comment: "")
        }
        if calendar.isDateInYesterday(ride.startDate) {
            return NSLocalizedString("ride_when_yesterday", comment: "")
        }
        return ride.startDate.formatted(.dateTime.weekday(.wide)).capitalized
    }

    private var subtitleLine: String? {
        guard showsDate else { return nil }
        if calendar.isDateInToday(ride.startDate) || calendar.isDateInYesterday(ride.startDate) {
            return ride.startDate.formatted(.dateTime.day().month(.wide))
        }
        if calendar.isDate(ride.startDate, equalTo: Date(), toGranularity: .year) {
            return ride.startDate.formatted(.dateTime.day().month(.wide))
        }
        return ride.startDate.formatted(.dateTime.day().month(.wide).year())
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Brand.Font.metric(18))
                .foregroundStyle(Brand.Color.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Brand.Color.hairline)
            .frame(width: 1, height: 28)
    }
}

struct RideRouteRibbon: View {
    let segments: [[CLLocationCoordinate2D]]
    var color: Color

    private var points: [CLLocationCoordinate2D] {
        segments.flatMap { $0 }
    }

    var body: some View {
        RideRouteShape(points: points)
            .stroke(color.gradient, style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
            .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: Brand.Radius.sm, style: .continuous))
            .accessibilityHidden(true)
    }
}

private struct RideRouteShape: Shape {
    let points: [CLLocationCoordinate2D]

    func path(in rect: CGRect) -> Path {
        guard let first = points.first else { return Path() }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for point in points.dropFirst() {
            minLat = min(minLat, point.latitude)
            maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude)
            maxLon = max(maxLon, point.longitude)
        }

        let latSpan = max(maxLat - minLat, 0.00008)
        let lonSpan = max(maxLon - minLon, 0.00008)
        let fitted = fittedRect(in: rect, latSpan: latSpan, lonSpan: lonSpan)

        var path = Path()
        for (index, point) in points.enumerated() {
            let x = fitted.minX + ((point.longitude - minLon) / lonSpan) * fitted.width
            let y = fitted.maxY - ((point.latitude - minLat) / latSpan) * fitted.height
            let mapped = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: mapped)
            } else {
                path.addLine(to: mapped)
            }
        }
        return path
    }

    private func fittedRect(in rect: CGRect, latSpan: Double, lonSpan: Double) -> CGRect {
        let aspect = lonSpan / latSpan
        let available = rect.insetBy(dx: 2, dy: 2)
        guard available.width > 0, available.height > 0 else { return available }
        let width: CGFloat
        let height: CGFloat
        if aspect > Double(available.width / available.height) {
            width = available.width
            height = max(available.width / CGFloat(aspect), 8)
        } else {
            height = available.height
            width = available.height * CGFloat(aspect)
        }
        return CGRect(
            x: available.midX - width / 2,
            y: available.midY - height / 2,
            width: width,
            height: height
        )
    }
}
