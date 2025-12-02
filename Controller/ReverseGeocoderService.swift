// Copyright H2so4 Consulting LLC 2025
// File: Services/ReverseGeocoderService.swift

import Foundation
import CoreLocation
import MapKit

// ReverseGeocoderService converts coordinates to a readable place name using MapKit search.
// end ReverseGeocoderService header
@MainActor
final class ReverseGeocoderService {
    static let shared = ReverseGeocoderService() // singleton
    private var currentSearch: MKLocalSearch? = nil

    private init() {} // end init

    // nearestPlaceName returns the closest human-friendly location label for a coordinate.
    // end nearestPlaceName
    func nearestPlaceName(near coordinate: CLLocationCoordinate2D) async throws -> String {
        currentSearch?.cancel()
        currentSearch = nil

        let region = MKCoordinateRegion(center: coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12))
        let request = MKLocalSearch.Request()
        request.region = region
        request.resultTypes = [.address, .pointOfInterest]

        let search = MKLocalSearch(request: request)
        currentSearch = search
        let response = try await search.start()
        currentSearch = nil

        guard let item = response.mapItems.first else { return "Unknown location" }

        let placemark = item.placemark
        let placeParts: [String] = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { value -> String? in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }

        let joinedParts = placeParts.joined(separator: ", ")
        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            if joinedParts.isEmpty { return name }
            return "\(name), \(joinedParts)"
        }

        if !joinedParts.isEmpty { return joinedParts }
        return "Unknown location"
    } // end nearestPlaceName
} // end ReverseGeocoderService
