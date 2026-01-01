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
    private let geocoder = CLGeocoder()
    private var currentSearch: MKLocalSearch? = nil

    private init() {} // end init

    // nearestPlaceName returns the closest human-friendly location label for a coordinate.
    // end nearestPlaceName
    func nearestPlaceName(near coordinate: CLLocationCoordinate2D) async throws -> String {
        currentSearch?.cancel(); currentSearch = nil

        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        if let placemark = try? await geocoder.reverseGeocodeLocation(location).first {
            let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
                .compactMap { part in
                    guard let trimmed = part?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
                    return trimmed
                }
            let joined = parts.joined(separator: ", ")
            if !joined.isEmpty { return joined }
        }

        let span = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
        let region = MKCoordinateRegion(center: coordinate, span: span)
        let req = MKLocalSearch.Request()
        req.region = region
        req.resultTypes = [.address, .pointOfInterest]
        let search = MKLocalSearch(request: req)
        currentSearch = search
        let resp = try await search.start()
        defer { currentSearch = nil }

        if let item = resp.mapItems.first {
            let placemark = item.placemark
            let parts = [placemark.locality, placemark.administrativeArea, placemark.country]
                .compactMap { value -> String? in
                    guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !trimmed.isEmpty else { return nil }
                    return trimmed
                }
            if let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
                if parts.isEmpty { return name }
                let regionLabel = parts.joined(separator: ", ")
                return [name, regionLabel].joined(separator: ", ")
            }
            let joined = parts.joined(separator: ", ")
            if !joined.isEmpty { return joined }
        }

        return "Unknown location"
    } // end nearestPlaceName
} // end ReverseGeocoderService
