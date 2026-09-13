import CoreLocation
import XCTest
@testable import MyBikeTracker

final class RideTrackGeometryTests: XCTestCase {
    func testTraveledDistanceSumsSegmentGapsSeparately() {
        let start = Date()
        let points = [
            location(lat: 50.45010, lon: 30.5234, at: start),
            location(lat: 50.45028, lon: 30.5234, at: start.addingTimeInterval(8)),
            location(lat: 50.47000, lon: 30.5500, at: start.addingTimeInterval(80)),
            location(lat: 50.47018, lon: 30.5500, at: start.addingTimeInterval(88))
        ]

        let segments = RideTrackGeometry.segments(from: points)
        XCTAssertEqual(segments.count, 2)

        let distance = RideTrackGeometry.traveledDistance(from: points)
        let first = points[0].distance(from: points[1])
        let second = points[2].distance(from: points[3])
        XCTAssertEqual(distance, first + second, accuracy: 0.5)
    }

    func testTeleportJumpIsADiscontinuity() {
        let start = Date()
        let a = location(lat: 50.45, lon: 30.52, at: start)
        let b = location(lat: 50.47, lon: 30.55, at: start.addingTimeInterval(2))
        XCTAssertTrue(RideTrackGeometry.isDiscontinuity(from: a, to: b))
    }

    func testNearbyPointsStayInOneSegment() {
        let start = Date()
        let points = (0..<6).map { index in
            location(
                lat: 50.4501 + Double(index) * 0.00008,
                lon: 30.5234,
                at: start.addingTimeInterval(Double(index) * 3)
            )
        }
        XCTAssertEqual(RideTrackGeometry.segments(from: points).count, 1)
    }

    func testSpeedSlicesBlendALargeJumpIntoAGradient() {
        let start = Date()
        let points = [
            location(lat: 50.45000, lon: 30.5234, at: start, speed: 2),
            location(lat: 50.45020, lon: 30.5234, at: start.addingTimeInterval(6), speed: 2),
            location(lat: 50.45040, lon: 30.5234, at: start.addingTimeInterval(12), speed: 10)
        ]
        let slices = RideTrackGeometry.speedColoredSlices(gpsSegments: [points])
        XCTAssertGreaterThan(slices.count, 2)
        XCTAssertLessThan(slices.first?.speedKmh ?? 99, 12)
        XCTAssertGreaterThan(slices.last?.speedKmh ?? 0, 16)
        XCTAssertEqual(SpeedTrackOutline.runs(from: slices).count, 1)
    }

    func testOutlineRunsStaySeparateAcrossAGPSGap() {
        let start = Date()
        let first = [
            location(lat: 50.45010, lon: 30.5234, at: start, speed: 5),
            location(lat: 50.45028, lon: 30.5234, at: start.addingTimeInterval(8), speed: 5)
        ]
        let second = [
            location(lat: 50.47000, lon: 30.5500, at: start.addingTimeInterval(80), speed: 5),
            location(lat: 50.47018, lon: 30.5500, at: start.addingTimeInterval(88), speed: 5)
        ]
        let slices = RideTrackGeometry.speedColoredSlices(gpsSegments: [first, second])
        XCTAssertEqual(SpeedTrackOutline.runs(from: slices).count, 2)
    }

    func testOutlineRunJoinsConnectedSlices() {
        let slices = [
            SpeedColoredSlice(
                id: "a",
                coordinates: [
                    CLLocationCoordinate2D(latitude: 50.45, longitude: 30.52),
                    CLLocationCoordinate2D(latitude: 50.451, longitude: 30.52)
                ],
                speedKmh: 8
            ),
            SpeedColoredSlice(
                id: "b",
                coordinates: [
                    CLLocationCoordinate2D(latitude: 50.451, longitude: 30.52),
                    CLLocationCoordinate2D(latitude: 50.452, longitude: 30.52)
                ],
                speedKmh: 22
            )
        ]
        let runs = SpeedTrackOutline.runs(from: slices)
        XCTAssertEqual(runs.count, 1)
        XCTAssertEqual(runs.first?.coordinates.count, 3)
    }

    private func location(lat: Double, lon: Double, at date: Date, speed: CLLocationSpeed = 5) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
            altitude: 170,
            horizontalAccuracy: 5,
            verticalAccuracy: 4,
            course: 0,
            speed: speed,
            timestamp: date
        )
    }
}
