//
//  OWMOneCall.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Minimal OpenWeather OneCall response for daily temps and POP
struct OWMOneCall: Codable {
    struct Daily: Codable {
        struct Temp: Codable { let min: Double; let max: Double } // Temp
        let dt: TimeInterval
        let temp: Temp
        let pop: Double?
    } // Daily
    let timezone_offset: Int?
    let daily: [Daily]
} // OWMOneCall
