//
//  MapHelpers.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 23.05.2025.
//

import CoreLocation
import MapKit
import SwiftUI

struct MapHelpers {
    // Используется по всему проекту — оставляем без изменений
    static func lineWidth(for region: MKCoordinateRegion?) -> CGFloat {
        guard let region = region else { return 2.0 }
        return lineWidth(for: region.span)
    }

    // Новая перегрузка — используется, если у тебя только span (например, в RideDetailView)
    static func lineWidth(for span: MKCoordinateSpan) -> CGFloat {
        return lineWidth(forSpan: span.latitudeDelta)
    }

    // Приватная общая логика
    private static func lineWidth(forSpan span: CLLocationDegrees) -> CGFloat {
        switch span {
        case ..<0.0005: return 35
        case ..<0.002: return 30
        case ..<0.003: return 25
        case ..<0.005: return 20
        case ..<0.008: return 10
        case ..<0.02: return 5
        case ..<0.1: return 2.5
        default: return 1.5
        }
    }

    static func bearing(
        from: CLLocationCoordinate2D,
        to: CLLocationCoordinate2D
    ) -> CLLocationDirection {
        let lat1 = from.latitude * .pi / 180
        let lon1 = from.longitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let lon2 = to.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }
}
