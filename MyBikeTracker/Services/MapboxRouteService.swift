//
//  MapboxRouteService.swift
//  MyBikeTracker
//
//  Created by Dima Sunko on 23.05.2025.
//
//  Отвечает за отправку маршрута на Mapbox Map Matching API и получение скорректированной линии.

import Foundation
import CoreLocation

class MapboxRouteService {

    /// Максимальное количество точек, допустимое Mapbox Map Matching API
    private let maxCoordinates = 100

    private var accessToken: String {
        guard let token = Bundle.main.object(forInfoDictionaryKey: "MAPBOX_ACCESS_TOKEN") as? String,
              !token.isEmpty else {
            assertionFailure("MAPBOX_ACCESS_TOKEN не задан в Info.plist")
            return ""
        }
        return token
    }

    func matchRoute(locations: [CLLocation], completion: @escaping (Result<[CLLocationCoordinate2D], Error>) -> Void) {
        guard !locations.isEmpty else {
            completion(.success([]))
            return
        }

        // Если точек больше лимита — прореживаем равномерно
        let sampled = sampleLocations(locations, maxCount: maxCoordinates)

        let coordinatesString = sampled
            .map { "\($0.coordinate.longitude),\($0.coordinate.latitude)" }
            .joined(separator: ";")

        let baseURL = "https://api.mapbox.com/matching/v5/mapbox/cycling/\(coordinatesString)"
        let params = "?access_token=\(accessToken)&geometries=geojson"

        guard let url = URL(string: baseURL + params) else {
            completion(.failure(MapboxError.invalidURL))
            return
        }

        let task = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(MapboxError.noData))
                return
            }

            do {
                let geojson = try JSONDecoder().decode(MapboxResponse.self, from: data)
                let coords = geojson.matchings.first?.geometry.coordinates
                    .map { CLLocationCoordinate2D(latitude: $0[1], longitude: $0[0]) } ?? []
                completion(.success(coords))
            } catch {
                completion(.failure(error))
            }
        }

        task.resume()
    }

    // MARK: - Вспомогательные методы

    /// Прореживает массив точек до maxCount, выбирая равномерно распределённые
    private func sampleLocations(_ locations: [CLLocation], maxCount: Int) -> [CLLocation] {
        guard locations.count > maxCount else { return locations }
        let step = Double(locations.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { locations[Int(round(Double($0) * step))] }
    }

    enum MapboxError: LocalizedError {
        case invalidURL
        case noData

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Некорректный URL запроса к Mapbox"
            case .noData: return "Mapbox не вернул данные"
            }
        }
    }
}

// MARK: - Response Models

struct MapboxResponse: Decodable {
    let matchings: [Matching]
}

struct Matching: Decodable {
    let geometry: Geometry
}

struct Geometry: Decodable {
    let coordinates: [[Double]]
}
