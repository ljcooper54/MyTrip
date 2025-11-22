//
//  Units.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Unit helpers for temperature formatting
enum Units {
    /// Convert °C to display string per user preference
    static func tempStringC(_ c: Double, isF: Bool) -> String {
        if isF {
            let f = (c * 9/5) + 32
            return "\(Int(round(f)))°F"
        }
        return "\(Int(round(c)))°C"
    } // tempStringC
} // Units
