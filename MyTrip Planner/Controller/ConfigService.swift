//
//  ConfigService.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Provides configuration (API keys) from Info.plist
enum ConfigService {
    /// OpenWeather API key from Info.plist (value: $(OPENWEATHER_API_KEY))
    static func openWeatherAPIKey() -> String {
        (Bundle.main.object(forInfoDictionaryKey: "OPENWEATHER_API_KEY") as? String) ?? ""
    } // openWeatherAPIKey
} // ConfigService
