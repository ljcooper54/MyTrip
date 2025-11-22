// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// Root planner that shows either a card carousel (iPhone portrait) or table (other)
struct PlannerView: View {
    @EnvironmentObject var store: TripStore
    @EnvironmentObject var app: AppState
    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize

    @State private var editing: Trip?
    @State private var showingEditor = false

    /// Trips whose date is today or in the future
    private var upcomingTrips: [Trip] {
        let today = Calendar.current.startOfDay(for: Date())
        return store.trips.filter { trip in
            Calendar.current.startOfDay(for: trip.date) >= today
        }
    } // upcomingTrips

    /// Use card carousel layout for iPhone portrait-style size classes
    private var useCards: Bool {
        hSize == .compact && vSize == .regular
    } // useCards

    /// Main body choosing between cards and table
    var body: some View {
        NavigationStack {
            Group {
                if useCards {
                    TripCardsView(
                        trips: upcomingTrips,
                        onEdit: { trip in
                            editing = trip
                            showingEditor = true
                        },
                        onDelete: { trip in
                            store.trips.removeAll { $0.id == trip.id }
                        },
                        onPhotoUpdate: { trip, newIdentifier in
                            if let idx = store.trips.firstIndex(where: { $0.id == trip.id }) {
                                var updated = store.trips[idx]
                                updated.photoLocalIdentifier = newIdentifier
                                store.trips[idx] = updated
                            }
                        }
                    )
                    .padding(.vertical, 16)
                } else {
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
                }
            }
            .navigationTitle("MyTrip")
            .toolbar {
                // Compact F / C control that fits in the nav bar
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Units", selection: $app.isFahrenheit) {
                        Text("°F").tag(true)
                        Text("°C").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 110)
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

