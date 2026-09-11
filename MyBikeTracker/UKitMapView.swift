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

    var body: some View {
        let _ = routeStyleRevision
        MapReader { proxy in
            Map(position: $viewModel.cameraPosition) {
                UserAnnotation()

                if let navRoute = viewModel.navigationRoute {
                    MapPolyline(navRoute)
                        .stroke(.blue, lineWidth: 5)

                    if let dest = viewModel.navigationDestination {
                        Marker("Destination", coordinate: dest)
                    }
                }

                ForEach(Array(resolvedLiveSegments.enumerated()), id: \.offset) { _, coords in
                    if coords.count > 1 {
                        MapPolyline(coordinates: coords)
                            .stroke(Color(uiColor: lineColor), lineWidth: 4)
                    }
                }

                if let lastCoord = resolvedLiveSegments.last?.last ?? liveCoordinates.last {
                    MapCircle(center: lastCoord, radius: 8)
                        .foregroundStyle(Color(uiColor: lineColor).opacity(0.4))
                }

                ForEach(rides) { ride in
                    let rideColor = ride.resolvedLineColor(defaultHex: defaultRideColorHex)
                    let width: CGFloat = ride.id == selectedRideID ? 7 : 4
                    ForEach(Array(ride.displaySegments.enumerated()), id: \.offset) { _, coords in
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(rideColor, lineWidth: width)
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                cameraDistance = context.camera.distance
            }
            .onMapCameraChange(frequency: .onEnd) { _ in
                if !viewModel.isProgrammaticRegionChange {
                    viewModel.shouldAutoCenter = false
                }
            }
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
