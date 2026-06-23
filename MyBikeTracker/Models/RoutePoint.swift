//
//  RoutePoint.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 19.05.2025.
//

import Foundation
import MapKit

struct RoutePoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}
