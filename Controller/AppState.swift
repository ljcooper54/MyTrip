// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import Combine

/// Global user preferences persisted via UserDefaults and published to views
final class AppState: ObservableObject {
    /// Temperature display in Fahrenheit if true, Celsius if false
    @Published var isFahrenheit: Bool {
        didSet { UserDefaults.standard.set(isFahrenheit, forKey: "isFahrenheit") }
    } // isFahrenheit

    /// Load from defaults (defaults to true on first launch)
    init() {
        if let v = UserDefaults.standard.object(forKey: "isFahrenheit") as? Bool {
            self.isFahrenheit = v
        } else {
            self.isFahrenheit = true
            UserDefaults.standard.set(true, forKey: "isFahrenheit")
        }
    } // init
} // AppState

