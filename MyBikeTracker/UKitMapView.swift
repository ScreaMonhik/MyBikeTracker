//
//  UKitMapView.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 20.05.2025.
//

import SwiftUI
import MapKit

struct UIKitMapView: UIViewRepresentable {
    let rides: [Ride]
    let lineColor: UIColor
    @ObservedObject var viewModel: MapViewModel

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        let viewModel: MapViewModel
        var lineColor: UIColor

        init(viewModel: MapViewModel, lineColor: UIColor) {
            self.viewModel = viewModel
            self.lineColor = lineColor
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            guard !viewModel.isProgrammaticRegionChange else { return }
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.shouldAutoCenter = false
            }
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = lineColor
                renderer.lineWidth = 4
                renderer.lineJoin = .round
                renderer.lineCap = .round
                return renderer
            } else if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = lineColor.withAlphaComponent(0.4)
                renderer.strokeColor = lineColor
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        @objc func handlePanGesture(_ sender: UIPanGestureRecognizer) {
            guard sender.state == .began else { return }
            DispatchQueue.main.async { [weak self] in
                self?.viewModel.shouldAutoCenter = false
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, lineColor: lineColor)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .none

        let panGesture = UIPanGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handlePanGesture(_:))
        )
        panGesture.delegate = context.coordinator
        mapView.addGestureRecognizer(panGesture)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Синхронизируем цвет линии с координатором (меняется из Settings)
        if context.coordinator.lineColor != lineColor {
            context.coordinator.lineColor = lineColor
        }

        if viewModel.isProgrammaticRegionChange,
           case let .region(region) = viewModel.cameraPosition {
            mapView.setRegion(region, animated: true)
            DispatchQueue.main.async {
                context.coordinator.viewModel.isProgrammaticRegionChange = false
            }
        }

        updateOverlays(on: mapView)
    }

    // MARK: - Оверлеи

    private func updateOverlays(on mapView: MKMapView) {
        mapView.removeOverlays(mapView.overlays)

        for ride in rides {
            let coords: [CLLocationCoordinate2D]
            if let matched = ride.matchedRoute, !matched.isEmpty {
                coords = matched.map { $0.clLocationCoordinate2D }
            } else {
                coords = ride.route.map { $0.clLocationCoordinate2D }
            }

            guard !coords.isEmpty else { continue }
            mapView.addOverlay(MKPolyline(coordinates: coords, count: coords.count))

            if let lastCoord = coords.last {
                mapView.addOverlay(MKCircle(center: lastCoord, radius: 8))
            }
        }
    }
}
