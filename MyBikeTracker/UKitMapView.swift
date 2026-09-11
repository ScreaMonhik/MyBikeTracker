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
    @ObservedObject var viewModel: MapViewModel

    private var resolvedLiveSegments: [[CLLocationCoordinate2D]] {
        if !liveSegments.isEmpty { return liveSegments }
        guard liveCoordinates.count > 1 else { return [] }
        return RideTrackGeometry.coordinateSegments(
            liveCoordinates,
            maxJump: RideTrackGeometry.liveGapDistance
        )
    }

    var body: some View {
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
                    ForEach(Array(ride.displaySegments.enumerated()), id: \.offset) { _, coords in
                        if coords.count > 1 {
                            MapPolyline(coordinates: coords)
                                .stroke(Color(uiColor: lineColor), lineWidth: 4)
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .onEnd) { _ in
                if !viewModel.isProgrammaticRegionChange {
                    viewModel.shouldAutoCenter = false
                }
            }
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
}
