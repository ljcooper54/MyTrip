// Copyright H2so4 Consulting LLC 2025
// File: Services/ReverseGeocoderService.swift

import Foundation
import CoreLocation
import MapKit

/// Reverse label lookup near a coordinate using `MKLocalSearch` (avoids deprecated CLGeocoder).
/// end final class ReverseGeocoderService
@MainActor
final class ReverseGeocoderService {
    static let shared = ReverseGeocoderService() // singleton
    private var currentSearch: MKLocalSearch? = nil
    private init() {} // end init

    /// Returns a human-friendly major place name closest to `coordinate`.
    /// end func nearestPlaceName(near:)
    func nearestPlaceName(near coordinate: CLLocationCoordinate2D) async throws -> String {
        currentSearch?.cancel(); currentSearch = nil
        let span = MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08) // a bit wider to hit major locales
        let region = MKCoordinateRegion(center: coordinate, span: span)
        let req = MKLocalSearch.Request()
        req.region = region
        let search = MKLocalSearch(request: req)
        currentSearch = search
        let resp = try await search.start()
        currentSearch = nil
        if let name = resp.mapItems.first?.name, !name.isEmpty { return name }
        return "Unknown location"
    } // end func nearestPlaceName(near:)
} // end final class ReverseGeocoderService

