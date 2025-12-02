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

        // Prefer a slightly wider span so we capture the nearest city/town rather than a tiny POI.
        let region = MKCoordinateRegion(center: coordinate,
                                        span: MKCoordinateSpan(latitudeDelta: 0.18, longitudeDelta: 0.18))

        // First attempt: ask MapKit for nearby addresses/POIs with a generic "city" query to bias towns.
        let primaryRequest = MKLocalSearch.Request()
        primaryRequest.region = region
        primaryRequest.naturalLanguageQuery = "city"
        primaryRequest.resultTypes = [.address, .pointOfInterest]

        // Backup attempt with an empty query if the first search returns nothing.
        let fallbackRequest = MKLocalSearch.Request()
        fallbackRequest.region = region
        fallbackRequest.resultTypes = [.address, .pointOfInterest]

        let response = try await performSearch(primaryRequest) ?? performSearch(fallbackRequest)
        guard let item = response?.mapItems.first else { return "Unknown location" }

        // Prefer a city-level description: City, State, Country. If unavailable, fall back to the item's name.
        let placemark = item.placemark
        let placeParts: [String] = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { value -> String? in
                guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                    return nil
                }
                return trimmed
            }

        let joinedParts = placeParts.joined(separator: ", ")
        if !joinedParts.isEmpty { return joinedParts }

        if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return name
        }

        return "Unknown location"
    } // end nearestPlaceName

    /// performSearch wraps MKLocalSearch start/cancel handling and returns nil when empty results are found.
    private func performSearch(_ request: MKLocalSearch.Request) async throws -> MKLocalSearch.Response? {
        currentSearch?.cancel(); currentSearch = nil
        let search = MKLocalSearch(request: request)
        currentSearch = search
        let response = try await search.start()
        currentSearch = nil
        return response.mapItems.isEmpty ? nil : response
    } // end func performSearch
} // end ReverseGeocoderService
