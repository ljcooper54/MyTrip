//
//  WeatherService.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Fetches daily Hi/Lo (°C) and POP (%) for a given trip date using OWM OneCall
enum WeatherService {
    /// Main entry: returns (hiC, loC, rain%)
    static func fetchDay(for trip: Trip) async throws -> (Double, Double, Int?) {
        let key = ConfigService.openWeatherAPIKey()
        guard !key.isEmpty else { throw AppError.missingAPIKey } // fetchDay

        var lat = trip.latitude
        var lon = trip.longitude
        if lat == nil || lon == nil {
            let g = try await GeocoderService.geocode(city: trip.city)
            lat = g.0; lon = g.1
        }
        guard let la = lat, let lo = lon else { throw AppError.noResults("coords") } // fetchDay

        for useV3 in [true, false] {
            let base = useV3 ? "https://api.openweathermap.org/data/3.0/onecall"
                             : "https://api.openweathermap.org/data/2.5/onecall"
            let q = "\(base)?lat=\(la)&lon=\(lo)&exclude=minutely,hourly,alerts,current&units=metric&appid=\(key)"
            guard let url = URL(string: q) else { continue } // fetchDay

            do {
                let (data, _) = try await HTTPClient.get(url, tag: useV3 ? "OWM.ONECALL.v3" : "OWM.ONECALL.v2")
                let oc = try JSONDecoder().decode(OWMOneCall.self, from: data)
                let offset = TimeInterval(oc.timezone_offset ?? 0)
                let cal = Calendar.current
                let pick = oc.daily.first {
                    let local = Date(timeIntervalSince1970: $0.dt + offset)
                    return cal.isDate(local, inSameDayAs: trip.date)
                } ?? oc.daily.first
                guard let d = pick else { continue } // fetchDay
                let hi = d.temp.max
                let lo = d.temp.min
                let rain = d.pop.map { Int(($0 * 100).rounded()) }
                return (hi, lo, rain)
            } catch {
                dlog("NET", "ONECALL \(useV3 ? "v3" : "v2.5") ERR \(error)")
                continue
            }
        } // for

        throw AppError.noResults("onecall") // fetchDay
    } // fetchDay
} // WeatherService
