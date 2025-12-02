// Copyright H2so4 Consulting LLC 2025
// File: Model/Trip.swift

import Foundation
import CoreLocation

/// Image provenance for trip photos.
/// TripImageSource
enum TripImageSource: String, Codable {
    case user
    case ai
} // end enum TripImageSource

/// Represents an image stored locally or referenced remotely.
/// - `fileURL`: local file (if we downloaded it)
/// - `remoteURL`: remote URL (e.g., public-domain link). We may have both; local takes precedence for display.
/// TripImage
struct TripImage: Identifiable, Codable, Equatable {
    let id: UUID
    let fileURL: URL?
    let remoteURL: URL?
    let createdAt: Date
    let source: TripImageSource

    init(
        id: UUID = UUID(),
        fileURL: URL?,
        remoteURL: URL?,
        createdAt: Date = Date(),
        source: TripImageSource
    ) {
        self.id = id
        self.fileURL = fileURL
        self.remoteURL = remoteURL
        self.createdAt = createdAt
        self.source = source
    } // end init
} // end struct TripImage

/// Core trip model used by views and services.
/// Trip
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

    /// Convenient coordinate bridging `latitude` / `longitude`.
    /// This is settable so it can be used with `Binding<CLLocationCoordinate2D?>`
    /// in views like `TripCardView` / `TripCardsView`.
    var coordinate: CLLocationCoordinate2D? {
        get {
            guard let lat = latitude, let lon = longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        set {
            latitude = newValue?.latitude
            longitude = newValue?.longitude
        }
    } // end var coordinate

    /// Name used for in-place editing on the card.
    /// Getter matches `displayName`, setter writes to `customName` and marks it as user-edited.
    var place: String {
        get { displayName }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                // User cleared the field – revert to auto naming.
                customName = nil
                isNameUserEdited = false
            } else {
                customName = trimmed
                isNameUserEdited = true
            }
        }
    } // end var place

    /// Human-friendly name for this trip:
    /// - prefer user-edited `customName`
    /// - then `city`
    /// - finally the raw `locationName`.
    var displayName: String {
        if let cn = customName,
           !cn.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return cn
        }
        if let c = city,
           !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return c
        }
        return locationName
    } // end var displayName

    /// Factory for a "blank" trip used by the "+" card affordance.
    /// Call as `Trip.blank()` from TripCardsView / store.
    static func blank(at date: Date = Date()) -> Trip {
        Trip(
            locationName: "",
            date: date,
            customName: nil,
            isNameUserEdited: false,
            city: nil,
            latitude: nil,
            longitude: nil,
            images: []
        )
    } // end static func blank
} // end struct Trip

