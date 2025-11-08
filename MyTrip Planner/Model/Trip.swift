//
//  Trip.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation

/// Core trip model persisted locally
struct Trip: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var city: String
    var date: Date
    var latitude: Double?
    var longitude: Double?
} // Trip
