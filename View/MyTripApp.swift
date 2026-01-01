//
//  MyTripApp.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import Combine

/// App entry point
@main
struct MyTripApp: App {
    @StateObject private var store = TripStore()
    @StateObject private var appState = AppState()
    @StateObject private var extensionRegistry = TripExtensionRegistry()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appState)
                .environmentObject(extensionRegistry)
        }
    } // body
} // MyTripApp
