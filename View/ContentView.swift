//
//  ContentView.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/6/25.
//


// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// Basic list + add/edit form shell
struct ContentView: View {
    @EnvironmentObject var store: TripStore
    @State private var editing: Trip?
    @State private var showingEditor = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.trips) { trip in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.city).font(.headline)
                        Text(DF.med.string(from: trip.date)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { editing = trip; showingEditor = true }
                } // ForEach
                .onDelete { idx in store.trips.remove(atOffsets: idx) }
            } // List
            .navigationTitle("MyTrip")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = Trip(city: "", date: Date()); showingEditor = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor, onDismiss: { store.sort() }) {
                TripFormView(trip: editing ?? Trip(city: "", date: Date())) { result in
                    if let idx = store.trips.firstIndex(where: { $0.id == result.id }) {
                        store.trips[idx] = result
                    } else {
                        store.trips.append(result)
                    }
                } // onSave
            } // .sheet
        } // NavigationStack
    } // body
} // ContentView
