//
//  GeocoderService.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// OpenWeather direct geocoding service
enum GeocoderService {
    /// Resolve "City" → (lat, lon) using OWM /geo/1.0/direct
    static func geocode(city: String) async throws -> (Double, Double) {
        let key = ConfigService.openWeatherAPIKey()
        guard !key.isEmpty else { throw AppError.missingAPIKey } // geocode

        let enc = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? city
        let urlStr = "https://api.openweathermap.org/geo/1.0/direct?q=\(enc)&limit=1&appid=\(key)"
        guard let url = URL(string: urlStr) else { throw AppError.badURL(urlStr) } // geocode

        let (data, _) = try await HTTPClient.get(url, tag: "OWM.GEOCODE")
        struct Direct: Codable { let lat: Double; let lon: Double } // Direct
        let arr = try JSONDecoder().decode([Direct].self, from: data)
        guard let first = arr.first else { throw AppError.noResults("geocode") } // geocode
        return (first.lat, first.lon)
    } // geocode
} // GeocoderService
