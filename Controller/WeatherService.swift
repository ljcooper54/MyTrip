// Copyright H2so4 Consulting LLC 2025
// File: Services/WeatherService.swift

import Foundation
import CoreLocation

/// Temperature unit used by the Weather layer (mirrors AppState.TempUnit).
/// end enum TemperatureUnit
enum TemperatureUnit: String { case c, f } // end enum TemperatureUnit

/// DTO for daily weather details we display in table/cards.
/// end struct DailyWeather
struct DailyWeather: Codable, Equatable {
    let date: Date
    let high: Double  // in display unit (C/F)
    let low: Double   // in display unit (C/F)
    let pop: Double   // probability of precipitation [0,1]
} // end struct DailyWeather

/// In-memory cache with 1h TTL keyed by (day, rounded lat/lon, unit).
/// end final class WeatherCache
final class WeatherCache {
    static let shared = WeatherCache()
    private struct Key: Hashable {
        let day: String
        let latKey: Int
        let lonKey: Int
        let unit: TemperatureUnit
    } // end struct Key
    private struct Entry { let timestamp: Date; let value: [DailyWeather] } // end struct Entry
    private var store: [Key: Entry] = [:]
    private init() {} // end init

    private func makeKey(for coord: CLLocationCoordinate2D, unit: TemperatureUnit, anchorDay: Date) -> Key {
        let latKey = Int((coord.latitude * 100).rounded())   // ~0.01°
        let lonKey = Int((coord.longitude * 100).rounded())
        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]
        let day = df.string(from: Calendar.current.startOfDay(for: anchorDay))
        return Key(day: day, latKey: latKey, lonKey: lonKey, unit: unit)
    } // end func makeKey

    func get(coord: CLLocationCoordinate2D, unit: TemperatureUnit, anchorDay: Date) -> [DailyWeather]? {
        let key = makeKey(for: coord, unit: unit, anchorDay: anchorDay)
        if let e = store[key], Date().timeIntervalSince(e.timestamp) < 3600 { return e.value }
        return nil
    } // end func get

    func set(coord: CLLocationCoordinate2D, unit: TemperatureUnit, anchorDay: Date, value: [DailyWeather]) {
        let key = makeKey(for: coord, unit: unit, anchorDay: anchorDay)
        store[key] = Entry(timestamp: Date(), value: value)
    } // end func set
} // end final class WeatherCache

/// OpenWeather API client (One Call) to fetch daily forecasts.
/// Requires `OPENWEATHER_API_KEY` in Info.plist.
/// end struct OpenWeatherAPI
struct OpenWeatherAPI {

    private func apiKey() throws -> String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "OPENWEATHER_API_KEY") as? String, !key.isEmpty else {
            throw NSError(domain: "OpenWeatherAPI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing OPENWEATHER_API_KEY"])
        }
        return key
    } // end func apiKey

    /// Fetch 7-day daily forecast and convert to our `DailyWeather` using desired unit.
    /// end func fetchDaily
    func fetchDaily(lat: Double, lon: Double, unit: TemperatureUnit) async throws -> [DailyWeather] {
        let key = try apiKey()
        let unitsParam = (unit == .c) ? "metric" : "imperial"
        var comps = URLComponents(string: "https://api.openweathermap.org/data/3.0/onecall")!
        comps.queryItems = [
            .init(name: "lat", value: String(lat)),
            .init(name: "lon", value: String(lon)),
            .init(name: "exclude", value: "minutely,hourly,alerts,current"),
            .init(name: "units", value: unitsParam),
            .init(name: "appid", value: key),
        ]
        let (data, resp) = try await URLSession.shared.data(from: comps.url!)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw NSError(domain: "OpenWeatherAPI", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bad response"])
        }
        struct OW: Decodable {
            struct Daily: Decodable {
                struct Temp: Decodable { let min: Double; let max: Double } // end struct Temp
                let dt: TimeInterval
                let temp: Temp
                let pop: Double?
            } // end struct Daily
            let daily: [Daily]
        } // end struct OW

        let decoded = try JSONDecoder().decode(OW.self, from: data)
        let out: [DailyWeather] = decoded.daily.map {
            DailyWeather(
                date: Date(timeIntervalSince1970: $0.dt),
                high: $0.temp.max,
                low: $0.temp.min,
                pop: min(max($0.pop ?? 0.0, 0.0), 1.0)
            )
        }
        return out
    } // end func fetchDaily
} // end struct OpenWeatherAPI

/// WeatherService: resolves coordinates and returns daily forecasts with caching.
/// end struct WeatherService
struct WeatherService {

    /// Returns the array of forecasted `DailyWeather` and also caches it for 1 hour.
    /// end func dailyForecast(for:unit:)
    func dailyForecast(for trip: Trip, unit: TemperatureUnit) async throws -> [DailyWeather] {
        let coord = try await GeocoderService.shared.geocode(for: trip)
        let anchor = Calendar.current.startOfDay(for: trip.date)
        if let cached = WeatherCache.shared.get(coord: coord, unit: unit, anchorDay: anchor) {
            return cached
        }
        let api = OpenWeatherAPI()
        let daily = try await api.fetchDaily(lat: coord.latitude, lon: coord.longitude, unit: unit)
        WeatherCache.shared.set(coord: coord, unit: unit, anchorDay: anchor, value: daily)
        return daily
    } // end func dailyForecast(for:unit:)

    /// Convenience to get a specific day’s forecast (matching trip date).
    /// end func forecastForTripDate
    func forecastForTripDate(for trip: Trip, unit: TemperatureUnit) async throws -> DailyWeather? {
        let days = try await dailyForecast(for: trip, unit: unit)
        let start = Calendar.current.startOfDay(for: trip.date)
        return days.first(where: { Calendar.current.isDate($0.date, inSameDayAs: start) })
    } // end func forecastForTripDate
} // end struct WeatherService

