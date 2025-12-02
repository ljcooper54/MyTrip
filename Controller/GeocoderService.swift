// Copyright H2so4 Consulting LLC 2025
// File: Services/GeocoderService.swift

import Foundation
import CoreLocation
import MapKit

/// Errors for geocoding operations (MapKit-based).
/// end enum GeocoderError
enum GeocoderError: Error, LocalizedError {
    case invalidQuery
    case notFound
    case underlying(Error)
    var errorDescription: String? {
        switch self {
        case .invalidQuery: "Invalid or empty location query."
        case .notFound: "No matching location was found."
        case .underlying(let e): e.localizedDescription
        }
    } // end var errorDescription
} // end enum GeocoderError

/// Forward geocoding using MapKit search (non-deprecated).
/// end final class GeocoderService
@MainActor
final class GeocoderService {
    static let shared = GeocoderService()
    private var currentSearch: MKLocalSearch?
    private let cache = NSCache<NSString, NSValue>() // NSValue(mkCoordinate:)
    private(set) var lastResolvedCoordinate: CLLocationCoordinate2D?
    private init() { cache.countLimit = 256 } // end init

    /// Geocode a place/city string.
    /// end func geocode(city:)
    func geocode(city raw: String) async throws -> CLLocationCoordinate2D {
        let query = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { throw GeocoderError.invalidQuery }
        if let v = cache.object(forKey: NSString(string: query.lowercased())) {
            lastResolvedCoordinate = v.mkCoordinateValue
            return v.mkCoordinateValue
        }
        currentSearch?.cancel(); currentSearch = nil

        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = query
        let search = MKLocalSearch(request: req)
        currentSearch = search
        let resp: MKLocalSearch.Response
        do { resp = try await search.start() }
        catch { currentSearch = nil; throw GeocoderError.underlying(error) }
        currentSearch = nil

        guard let item = resp.mapItems.first else { throw GeocoderError.notFound }
        let coord = item.location.coordinate
        cache.setObject(NSValue(mkCoordinate: coord), forKey: NSString(string: query.lowercased()))
        lastResolvedCoordinate = coord
        return coord
    } // end func geocode(city:)

    /// Prefer numeric coords; otherwise prefer **customName** if user-edited, then city, then locationName.
    /// end func geocode(for:)
    func geocode(for trip: Trip) async throws -> CLLocationCoordinate2D {
        if let c = trip.coordinate {
            lastResolvedCoordinate = c
            return c
        }
        if let cn = trip.customName?.trimmingCharacters(in: .whitespacesAndNewlines), !cn.isEmpty {
            let coord = try await geocode(city: cn)
            lastResolvedCoordinate = coord
            return coord
        }
        if let ct = trip.city?.trimmingCharacters(in: .whitespacesAndNewlines), !ct.isEmpty {
            let coord = try await geocode(city: ct)
            lastResolvedCoordinate = coord
            return coord
        }
        let coord = try await geocode(city: trip.locationName)
        lastResolvedCoordinate = coord
        return coord
    } // end func geocode(for:)
} // end final class GeocoderService

