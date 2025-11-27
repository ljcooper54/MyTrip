// Copyright H2so4 Consulting LLC 2025
// File: App/AppState.swift

import Foundation
import CoreLocation
import Combine

/// Global UI/app state such as temperature unit and last picked location.
/// end final class AppState
final class AppState: ObservableObject {
    enum TempUnit: String, Codable, CaseIterable { case c, f } // Celsius / Fahrenheit
    // Persisting through UserDefaults for simplicity; consider Keychain/Store later.

    @Published var unit: TempUnit {
        didSet { UserDefaults.standard.set(unit.rawValue, forKey: "temp_unit") }
    } // end var unit

    @Published var lastPickedCoordinate: CLLocationCoordinate2D? {
        didSet {
            guard let c = lastPickedCoordinate else {
                UserDefaults.standard.removeObject(forKey: "last_lat")
                UserDefaults.standard.removeObject(forKey: "last_lon")
                return
            }
            UserDefaults.standard.set(c.latitude, forKey: "last_lat")
            UserDefaults.standard.set(c.longitude, forKey: "last_lon")
        }
    } // end var lastPickedCoordinate

    init() {
        if let raw = UserDefaults.standard.string(forKey: "temp_unit"),
           let u = TempUnit(rawValue: raw) {
            unit = u
        } else { unit = .f }
        if let lat = UserDefaults.standard.object(forKey: "last_lat") as? Double,
           let lon = UserDefaults.standard.object(forKey: "last_lon") as? Double {
            lastPickedCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            lastPickedCoordinate = nil
        }
    } // end init
} // end final class AppState

