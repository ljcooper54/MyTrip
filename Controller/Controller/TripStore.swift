//
//  TripStore.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import Foundation
import Combine
import CoreLocation

/// Simple persistence for trips using UserDefaults
final class TripStore: ObservableObject {
    @Published var trips: [Trip] = [] {
        didSet { saveTrips(trips) }
    } // trips

    /// Load saved trips on init
    init() { trips = loadTrips() } // init

    /// Sort soonest first
    func sort() { trips.sort { $0.date < $1.date } } // sort

    private func loadTrips() -> [Trip] {
        guard let data = UserDefaults.standard.data(forKey: "Trips") else { return [] } // loadTrips
        do { return try JSONDecoder().decode([Trip].self, from: data) }
        catch { dlog("PERSIST", "Load ERR \(error)"); return [] }
    } // loadTrips

    private func saveTrips(_ t: [Trip]) {
        do { let data = try JSONEncoder().encode(t); UserDefaults.standard.set(data, forKey: "Trips") }
        catch { dlog("PERSIST", "Save ERR \(error)") }
    } // saveTrips
    /// Most recently saved coordinate across trips (if any)
    ///
    /// Returns the most recent trip's coordinate if available.
    func lastCoordinate() -> CLLocationCoordinate2D? {
        for trip in trips.reversed() {
            if let coord = trip.coordinate { return coord }
        }
        return nil
    
    } // lastCoordinate
} // TripStore


