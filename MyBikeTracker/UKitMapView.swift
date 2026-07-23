//
//  UKitMapView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI
import MapKit

struct UIKitMapView: View {
    let rides: [Ride]
    let lineColor: UIColor
    @ObservedObject var viewModel: MapViewModel

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

                ForEach(Array(rides.enumerated()), id: \.offset) { index, ride in
                    let coords = routeCoordinates(for: ride)
                    if !coords.isEmpty {
                        MapPolyline(coordinates: coords)
                            .stroke(Color(uiColor: lineColor), lineWidth: 4)
                        
                        if let lastCoord = coords.last {
                            MapCircle(center: lastCoord, radius: 8)
                                .foregroundStyle(Color(uiColor: lineColor).opacity(0.4))
                        }
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
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

    private func routeCoordinates(for ride: Ride) -> [CLLocationCoordinate2D] {
        if let matched = ride.matchedRoute, !matched.isEmpty {
            return matched.map { $0.clLocationCoordinate2D }
        } else {
            return ride.route.map { $0.clLocationCoordinate2D }
        }
    }
}
