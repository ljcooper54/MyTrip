// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// Root planner list with add/edit and per-row weather
struct PlannerView: View {
    @EnvironmentObject var store: TripStore
    @EnvironmentObject var app: AppState
    @State private var editing: Trip?
    @State private var showingEditor = false

    /// Trips whose date is today or in the future
    private var upcomingTrips: [Trip] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.trips.filter { trip in
            Calendar.current.startOfDay(for: trip.date) >= today
        }
    } // upcomingTrips

    var body: some View {
        NavigationStack {
            List {
                ForEach(upcomingTrips) { trip in
                    TripRowView(trip: trip)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            editing = trip
                            showingEditor = true
                        }
                } // ForEach
                .onDelete { indexSet in
                    // Map deletions from filtered list back to the master trip list
                    let idsToDelete = indexSet.map { upcomingTrips[$0].id }
                    store.trips.removeAll { trip in
                        idsToDelete.contains(trip.id)
                    }
                }
            } // List
            .navigationTitle("MyTrip")
            .toolbar {
                // Compact F / C control that fits in the nav bar
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Units", selection: $app.isFahrenheit) {
                        Text("°F").tag(true)
                        Text("°C").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)   // keeps it from being squashed
                    .accessibilityLabel("Temperature Units")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editing = Trip(city: "",
                                       date: Date(),
                                       latitude: nil,
                                       longitude: nil)
                        showingEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingEditor,
                   onDismiss: { store.sort() }) {
                TripFormView(trip: editing ?? Trip(city: "",
                                                   date: Date())) { result in
                    if let idx = store.trips.firstIndex(where: { $0.id == result.id }) {
                        store.trips[idx] = result
                    } else {
                        store.trips.append(result)
                    }
                } // onSave
            } // sheet
        } // NavigationStack
    } // body
} // PlannerView

