//
//  DF.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Common date formatters
enum DF {
    /// yyyy-MM-dd for API day selection
    static let ymd: DateFormatter = { let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"; return df }() // ymd
    /// Medium date for UI
    static let med: DateFormatter = { let df = DateFormatter(); df.dateStyle = .medium; return df }() // med
} // DF

// =======================================
// File: Utilities/Date+Helpers.swift
// =======================================

extension Date {
    var startOfDayUTC: Date {
        Calendar.current.startOfDay(for: self)
    }
}
