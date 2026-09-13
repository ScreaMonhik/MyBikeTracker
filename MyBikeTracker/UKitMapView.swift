//
//  UKitMapView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI
import MapKit

struct UIKitMapView: View {
    var rides: [Ride] = []
    var liveCoordinates: [CLLocationCoordinate2D] = []
    var liveSegments: [[CLLocationCoordinate2D]] = []
    var liveSpeedSlices: [SpeedColoredSlice] = []
    let lineColor: UIColor
    var defaultRideColorHex: String = RouteLineColor.defaultHistoryHex
    var routeStyleRevision: Int = 0
    var selectedRideID: UUID?
    var ridePopup: RideLinePopupTarget?
    var isRidePopupVisible: Bool = false
    var ridesViewModel: RidesViewModel?
    var onRideTap: ((Ride, CLLocationCoordinate2D) -> Void)?
    var onEmptyMapTap: (() -> Void)?
    @ObservedObject var viewModel: MapViewModel

    @State private var cameraDistance: CLLocationDistance = 2_500
    @State private var canvasSize: CGSize = .zero
    @State private var popupSize = CGSize(width: 268, height: 220)

    private var resolvedLiveSegments: [[CLLocationCoordinate2D]] {
        if !liveSegments.isEmpty { return liveSegments }
        guard liveCoordinates.count > 1 else { return [] }
        return RideTrackGeometry.coordinateSegments(
            liveCoordinates,
            maxJump: RideTrackGeometry.liveGapDistance
        )
    }

    /// Tip of the drawn live track, otherwise the app GPS fix — never MapKit's system puck.
    private var riderCoordinate: CLLocationCoordinate2D? {
        if let tip = resolvedLiveSegments.last?.last ?? liveCoordinates.last {
            return tip
        }
        return viewModel.displayCoordinate ?? viewModel.locationService.currentLocation?.coordinate
    }

    private var riderHeading: Angle? {
        if viewModel.displayCourse >= 0 {
            return Angle(degrees: viewModel.displayCourse)
        }
        let coords = liveCoordinates
        guard coords.count >= 2 else { return nil }
        return Angle(degrees: MapHelpers.bearing(from: coords[coords.count - 2], to: coords[coords.count - 1]))
    }

    private var isRiderLive: Bool {
        viewModel.startTime != nil && !viewModel.isPaused
    }

    private var livePaceScale: PaceScale {
        viewModel.livePaceScale
    }

    private var riderAccent: Color {
        if viewModel.startTime != nil {
            return SpeedHeatmap.color(forKmh: viewModel.currentSpeed, scale: livePaceScale)
        }
        return Color(uiColor: lineColor)
    }

    private var visibleRides: [Ride] {
        if rides.count <= 40 { return rides }
        var limited = Array(rides.prefix(40))
        if let selected = rides.first(where: { $0.id == selectedRideID }),
           !limited.contains(where: { $0.id == selected.id }) {
            limited.insert(selected, at: 0)
        }
        return limited
    }

    private var newestRideID: UUID? { rides.first?.id }

    private func paceScale(for ride: Ride) -> PaceScale {
        ridesViewModel?.paceScale(for: ride) ?? .default
    }

    private func shouldDrawHeatmap(for ride: Ride) -> Bool {
        guard ride.hasSpeedHeatmapData else { return false }
        return MapRideHeatmap.isActive(
            rideID: ride.id,
            newestRideID: newestRideID,
            selectedRideID: selectedRideID
        )
    }

    var body: some View {
        let _ = routeStyleRevision
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition) {
                if let riderCoordinate {
                    Annotation(
                        "",
                        coordinate: riderCoordinate,
                        anchor: .center
                    ) {
                        RiderPuck(
                            heading: riderHeading,
                            isLive: isRiderLive,
                            accent: riderAccent
                        )
                    }
                    .annotationTitles(.hidden)
                }

                if let navRoute = viewModel.navigationRoute {
                    MapPolyline(navRoute)
                        .stroke(.blue, lineWidth: 5)

                    if let dest = viewModel.navigationDestination {
                        Marker("Destination", coordinate: dest)
                    }
                }

                if !liveSpeedSlices.isEmpty {
                    speedTrackMapContent(slices: liveSpeedSlices, scale: livePaceScale)
                } else {
                    ForEach(Array(resolvedLiveSegments.enumerated()), id: \.offset) { _, coords in
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(Color(uiColor: lineColor), lineWidth: 4)
                        }
                    }
                }

                ForEach(visibleRides) { ride in
                    let rideColor = ride.resolvedLineColor(defaultHex: defaultRideColorHex)
                    let width: CGFloat = ride.id == selectedRideID ? 7 : 4
                    if shouldDrawHeatmap(for: ride) {
                        speedTrackMapContent(
                            slices: ride.speedColoredSlices,
                            scale: paceScale(for: ride),
                            lineWidth: width,
                            idPrefix: ride.id.uuidString
                        )
                    } else {
                        ForEach(Array(ride.displaySegments.enumerated()), id: \.offset) { _, coords in
                            if coords.count > 1 {
                                MapPolyline(coordinates: coords)
                                    .stroke(rideColor, lineWidth: width)
                            }
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                cameraDistance = context.camera.distance
                viewModel.handleLiveCameraRegion(context.region)
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                viewModel.handleCameraIdle(context.region)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { _ in
                        viewModel.breakAutoCenterFromUserInteraction()
                    }
            )
            .background {
                GeometryReader { geo in
                    Color.clear
                        .onAppear { canvasSize = geo.size }
                        .onChange(of: geo.size) { _, newSize in
                            canvasSize = newSize
                        }
                }
            }
            .overlay(alignment: .topLeading) {
                if let ridePopup, let ridesViewModel,
                   let point = proxy.convert(ridePopup.coordinate, to: .local) {
                    ridePopupView(
                        ridePopup: ridePopup,
                        ridesViewModel: ridesViewModel,
                        anchor: point
                    )
                }
            }
            .simultaneousGesture(
                SpatialTapGesture()
                    .onEnded { event in
                        handleMapTap(at: event.location, proxy: proxy)
                    }
            )
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .onEnded { value in
                        switch value {
                        case .second(true, let drag):
                            if let location = drag?.location,
                               let coordinate = proxy.convert(location, from: .local) {
                                Task {
                                    await viewModel.calculateRoute(to: coordinate)
                                }
                            }
                        default:
                            break
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private func ridePopupView(
        ridePopup: RideLinePopupTarget,
        ridesViewModel: RidesViewModel,
        anchor: CGPoint
    ) -> some View {
        let targetScale = RideLinePopupPlacement.readableScale(cameraDistance: cameraDistance)
        let scale = isRidePopupVisible ? targetScale : 0.16
        let visualHeight = popupSize.height * targetScale
        let flip = RideLinePopupPlacement.flipBelow(
            anchorY: anchor.y,
            popupHeight: visualHeight,
            canvasHeight: canvasSize.height
        )
        let cardCenterX = RideLinePopupPlacement.clampedCenterX(
            anchorX: anchor.x,
            popupWidth: popupSize.width * targetScale,
            canvasWidth: canvasSize.width
        )
        let originX = anchor.x - popupSize.width / 2
        let originY = flip ? anchor.y : anchor.y - popupSize.height
        let cardNudge = targetScale > 0 ? (cardCenterX - anchor.x) / targetScale : 0

        RideLineInfoPopup(
            ride: ridePopup.ride,
            ridesViewModel: ridesViewModel,
            flipBelow: flip,
            cardNudge: cardNudge
        )
        .id(ridePopup.id)
        .background {
            GeometryReader { popupGeo in
                Color.clear
                    .preference(key: RideLinePopupSizeKey.self, value: popupGeo.size)
            }
        }
        .onPreferenceChange(RideLinePopupSizeKey.self) { popupSize = $0 }
        .scaleEffect(scale, anchor: flip ? .top : .bottom)
        .opacity(isRidePopupVisible ? 1 : 0)
        .offset(
            x: originX,
            y: originY + (isRidePopupVisible ? 0 : (flip ? -14 : 14))
        )
        .allowsHitTesting(isRidePopupVisible)
    }

    private func handleMapTap(at location: CGPoint, proxy: MapProxy) {
        guard onRideTap != nil || onEmptyMapTap != nil else { return }

        if isRidePopupVisible, popupFrame(proxy: proxy)?.contains(location) == true {
            return
        }

        if !rides.isEmpty,
           let hit = RideLineHitTesting.nearestHit(
            at: location,
            rides: rides,
            convert: { proxy.convert($0, to: .local) }
           ) {
            onRideTap?(hit.ride, hit.coordinate)
            return
        }

        onEmptyMapTap?()
    }

    private func popupFrame(proxy: MapProxy) -> CGRect? {
        guard let ridePopup, let anchor = proxy.convert(ridePopup.coordinate, to: .local) else {
            return nil
        }
        let targetScale = RideLinePopupPlacement.readableScale(cameraDistance: cameraDistance)
        let width = popupSize.width * targetScale
        let height = popupSize.height * targetScale
        let flip = RideLinePopupPlacement.flipBelow(
            anchorY: anchor.y,
            popupHeight: height,
            canvasHeight: canvasSize.height
        )
        let centerX = RideLinePopupPlacement.clampedCenterX(
            anchorX: anchor.x,
            popupWidth: popupSize.width,
            canvasWidth: canvasSize.width
        )
        let minX = centerX - width / 2
        let minY = flip ? anchor.y : anchor.y - height
        return CGRect(x: minX, y: minY, width: width, height: height).insetBy(dx: -12, dy: -12)
    }
}

private struct RideLinePopupSizeKey: SwiftUI.PreferenceKey {
    static var defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}
