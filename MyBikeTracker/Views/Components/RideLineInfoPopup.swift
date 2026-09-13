import SwiftUI
import CoreLocation

struct RideLinePopupTarget {
    let id: UUID
    let ride: Ride
    let coordinate: CLLocationCoordinate2D

    init(_ ride: Ride, coordinate: CLLocationCoordinate2D) {
        self.id = ride.id
        self.ride = ride
        self.coordinate = coordinate
    }
}

enum RideLinePopupMotion {
    static let present = Animation.spring(response: 0.46, dampingFraction: 0.74)
    static let dismiss = Animation.spring(response: 0.34, dampingFraction: 0.9)
}

enum RideLinePopupPlacement {
    static func readableScale(cameraDistance: CLLocationDistance) -> CGFloat {
        let clamped = min(max(cameraDistance, 350), 24_000)
        let t = (log(clamped) - log(350)) / (log(24_000) - log(350))
        return 1.18 - (0.22 * t)
    }

    static func flipBelow(anchorY: CGFloat, popupHeight: CGFloat, canvasHeight: CGFloat) -> Bool {
        let topLimit: CGFloat = 64
        let bottomLimit = canvasHeight - 16
        let fitsAbove = anchorY - popupHeight > topLimit
        let fitsBelow = anchorY + popupHeight < bottomLimit
        if !fitsAbove && fitsBelow { return true }
        return false
    }

    static func clampedCenterX(anchorX: CGFloat, popupWidth: CGFloat, canvasWidth: CGFloat) -> CGFloat {
        let half = popupWidth / 2
        let margin: CGFloat = 12
        return min(max(anchorX, margin + half), max(margin + half, canvasWidth - margin - half))
    }
}

struct RideLineInfoPopup: View {
    let ride: Ride
    @ObservedObject var ridesViewModel: RidesViewModel
    var flipBelow: Bool = false
    var cardNudge: CGFloat = 0

    @AppStorage(PreferenceKey.distanceUnitSystem) private var unitSystemRaw = DistanceUnitSystem.metric.rawValue
    @AppStorage(.historyRouteColorKey) private var historyColorHex: String = RouteLineColor.defaultHistoryHex

    var body: some View {
        let _ = ridesViewModel.routeStyleRevision
        let rideColor = ride.resolvedLineColor(defaultHex: historyColorHex)

        VStack(spacing: 4) {
            if flipBelow { pin(rideColor) }
            card(rideColor)
                .offset(x: cardNudge)
            if !flipBelow { pin(rideColor) }
        }
        .accessibilityElement(children: .contain)
    }

    private func card(_ rideColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(rideColor)
                    .frame(width: 9, height: 9)
                Text(ride.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(Brand.Font.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
            }

            if let bikeName = ridesViewModel.bike(for: ride)?.name {
                Text(bikeName)
                    .font(Brand.Font.caption)
                    .foregroundStyle(Brand.Color.muted)
                    .lineLimit(1)
            }

            HStack(spacing: 0) {
                metric(LocalizedStringKey("distance_title"), RideFormatters.distance(meters: ride.distance))
                divider
                metric(LocalizedStringKey("duration_title"), ride.duration.formattedAsTimer)
            }

            HStack(spacing: 0) {
                metric(LocalizedStringKey("average_speed_title"), RideFormatters.speed(kmh: ride.averageSpeed))
                divider
                metric(LocalizedStringKey("max_speed_title"), RideFormatters.speed(kmh: ride.maxSpeed))
            }

            if ride.resolvedElevationGain > 0 {
                metric(LocalizedStringKey("elevation_title"), RideFormatters.elevation(meters: ride.resolvedElevationGain))
                    .frame(maxWidth: .infinity)
            }

            RideLineColorEditor(ride: ride, ridesViewModel: ridesViewModel, compact: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(width: 268)
        .liquidGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.16), radius: 16, y: 8)
    }

    private func pin(_ rideColor: Color) -> some View {
        Circle()
            .fill(rideColor)
            .frame(width: 9, height: 9)
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.85), lineWidth: 1.5)
            }
            .shadow(color: rideColor.opacity(0.45), radius: 4)
    }

    private var divider: some View {
        Rectangle()
            .fill(.primary.opacity(0.12))
            .frame(width: 1, height: 32)
    }

    private func metric(_ title: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(title)
                .font(Brand.Font.micro)
                .foregroundStyle(Brand.Color.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(Brand.Font.metric(16))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
