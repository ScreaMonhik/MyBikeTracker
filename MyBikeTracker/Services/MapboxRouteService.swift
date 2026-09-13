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

    /// Map Matching accepts 100 coordinates per request; longer rides are chunked.
    private let maxCoordinates = 100
    private let chunkSize = 96
    private let chunkOverlap = 2

    var isConfigured: Bool { !accessToken.isEmpty }

    private var accessToken: String {
        let raw = Bundle.main.object(forInfoDictionaryKey: "MAPBOX_ACCESS_TOKEN") as? String
            ?? Bundle.main.infoDictionary?["MAPBOX_ACCESS_TOKEN"] as? String
            ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("$(") {
            return ""
        }
        return trimmed
    }

    func matchRoute(locations: [CLLocation]) async -> [CLLocationCoordinate2D] {
        await withCheckedContinuation { continuation in
            matchRoute(locations: locations) { result in
                switch result {
                case .success(let coords):
                    continuation.resume(returning: coords)
                case .failure:
                    continuation.resume(returning: [])
                }
            }
        }
    }

    func matchRoute(locations: [CLLocation], completion: @escaping (Result<[CLLocationCoordinate2D], Error>) -> Void) {
        guard !locations.isEmpty else {
            completion(.success([]))
            return
        }
        guard !accessToken.isEmpty else {
            completion(.success([]))
            return
        }

        let chunks = chunkLocations(locations)
        matchChunks(chunks, token: accessToken) { result in
            completion(result)
        }
    }

    // MARK: - Вспомогательные методы

    private func chunkLocations(_ locations: [CLLocation]) -> [[CLLocation]] {
        guard locations.count > maxCoordinates else { return [locations] }
        var chunks: [[CLLocation]] = []
        var start = 0
        while start < locations.count {
            let end = min(start + chunkSize, locations.count)
            chunks.append(Array(locations[start..<end]))
            if end == locations.count { break }
            start = max(end - chunkOverlap, start + 1)
        }
        return chunks
    }

    private func matchChunks(
        _ chunks: [[CLLocation]],
        token: String,
        completion: @escaping (Result<[CLLocationCoordinate2D], Error>) -> Void
    ) {
        func step(_ index: Int, assembled: [CLLocationCoordinate2D]) {
            guard index < chunks.count else {
                completion(.success(assembled))
                return
            }
            matchSingleChunk(chunks[index], token: token) { result in
                switch result {
                case .failure(let error):
                    completion(.failure(error))
                case .success(let coords):
                    var next = assembled
                    if next.isEmpty {
                        next = coords
                    } else if coords.count > 1 {
                        next.append(contentsOf: coords.dropFirst())
                    }
                    step(index + 1, assembled: next)
                }
            }
        }
        step(0, assembled: [])
    }

    private func matchSingleChunk(
        _ locations: [CLLocation],
        token: String,
        completion: @escaping (Result<[CLLocationCoordinate2D], Error>) -> Void
    ) {
        let sampled = sampleLocations(locations, maxCount: maxCoordinates)
        let coordinatesString = sampled
            .map { "\($0.coordinate.longitude),\($0.coordinate.latitude)" }
            .joined(separator: ";")

        let baseURL = "https://api.mapbox.com/matching/v5/mapbox/cycling/\(coordinatesString)"
        let params = "?access_token=\(token)&geometries=geojson"

        guard let url = URL(string: baseURL + params) else {
            completion(.failure(MapboxError.invalidURL))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
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
        }.resume()
    }

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
