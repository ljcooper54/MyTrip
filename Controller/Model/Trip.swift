// Copyright H2so4 Consulting LLC 2025
// File: Model/Trip.swift

import Foundation
import CoreLocation

/// Image provenance for trip photos.
/// end enum TripImageSource
enum TripImageSource: String, Codable { case user, ai } // end enum TripImageSource

/// Represents an image stored locally or referenced remotely.
/// - `fileURL`: local file (if we downloaded it)
/// - `remoteURL`: remote URL (e.g., public-domain link). We may have both; local takes precedence for display.
/// end struct TripImage
struct TripImage: Identifiable, Codable, Equatable {
    let id: UUID
    let fileURL: URL?
    let remoteURL: URL?
    let createdAt: Date
    let source: TripImageSource

    init(id: UUID = UUID(), fileURL: URL?, remoteURL: URL?, createdAt: Date = Date(), source: TripImageSource) {
        self.id = id
        self.fileURL = fileURL
        self.remoteURL = remoteURL
        self.createdAt = createdAt
        self.source = source
    } // end init
} // end struct TripImage

/// Core trip model used by views and services.
/// end struct Trip
struct Trip: Identifiable, Codable, Equatable {
    let id: UUID
    var locationName: String
    var date: Date
    var customName: String?
    var isNameUserEdited: Bool
    var city: String?
    var latitude: Double?
    var longitude: Double?
    var images: [TripImage]

    init(
        id: UUID = UUID(),
        locationName: String,
        date: Date,
        customName: String? = nil,
        isNameUserEdited: Bool = false,
        city: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        images: [TripImage] = []
    ) {
        self.id = id
        self.locationName = locationName
        self.date = date
        self.customName = customName
        self.isNameUserEdited = isNameUserEdited
        self.city = city
        self.latitude = latitude
        self.longitude = longitude
        self.images = images
    } // end init

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    } // end var coordinate

    var displayName: String {
        if let cn = customName, !cn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return cn }
        if let c = city, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return c }
        return locationName
    } // end var displayName
} // end struct Trip

