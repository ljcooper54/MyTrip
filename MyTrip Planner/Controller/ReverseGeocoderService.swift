//
//  ReverseGeocoderService.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation
import CoreLocation

/// Converts coordinates to a friendly place name (city, region, country)
enum ReverseGeocoderService {
    /// Reverse geocode coordinates to "City, State, Country"
    static func name(lat: Double, lon: Double) async -> String? {
        let geocoder = CLGeocoder()
        do {
            let marks = try await geocoder.reverseGeocodeLocation(.init(latitude: lat, longitude: lon))
            if let p = marks.first {
                let parts = [p.locality, p.administrativeArea, p.country].compactMap { $0 }
                let s = parts.joined(separator: ", ")
                return s.isEmpty ? nil : s
            }
        } catch {
            dlog("MAP", "ReverseGeocode ERR \(error)")
        }
        return nil
    } // name
} // ReverseGeocoderService
