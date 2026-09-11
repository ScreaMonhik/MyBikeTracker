import CoreLocation
import MapKit

/// MapKit directions that stay on roads, bike paths, or sidewalks.
enum RoadPathService {
    static func routeOnRoads(
        from start: CLLocationCoordinate2D,
        to end: CLLocationCoordinate2D
    ) async -> [CLLocationCoordinate2D] {
        let types: [MKDirectionsTransportType] = [.cycling, .walking, .automobile]
        for transportType in types {
            let request = MKDirections.Request()
            request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
            request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end))
            request.transportType = transportType
            request.requestsAlternateRoutes = false

            guard let response = try? await MKDirections(request: request).calculate(),
                  let polyline = response.routes.first?.polyline else {
                continue
            }
            let coordinates = coordinates(from: polyline)
            if coordinates.count >= 2 {
                return coordinates
            }
        }
        return []
    }

    static func coordinates(from polyline: MKPolyline) -> [CLLocationCoordinate2D] {
        var coords = Array(
            repeating: kCLLocationCoordinate2DInvalid,
            count: polyline.pointCount
        )
        polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
        return coords.filter { CLLocationCoordinate2DIsValid($0) }
    }
}
