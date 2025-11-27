// Copyright H2so4 Consulting LLC 2025
// File: View/ContentView.swift

import SwiftUI

/// Root container with adaptive layout and inline "Add Card" editing.
/// - iPad or landscape ⇒ table
/// - iPhone portrait ⇒ carousel cards
/// - "+" adds a draft card that is edited **in place** with Save/Cancel buttons.
/// end struct ContentView
struct ContentView: View {

    // MARK: - Environment

    @Environment(\.horizontalSizeClass) private var hSize
    @Environment(\.verticalSizeClass) private var vSize
    @StateObject private var appState = AppState()

    // MARK: - State

    @State private var trips: [Trip] = []
    @State private var editingTripIDs: Set<UUID> = []          // Tracks which cards are in edit mode

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if shouldShowTable {
                    TripTableView(trips: trips).environmentObject(appState)
                } else {
                    TripCardsView(trips: $trips)
                        .environmentObject(appState)
                        // Inject per-card edit state handlers
                        .environment(\.tripEditControls, TripEditControls(
                            isEditing: { id in editingTripIDs.contains(id) },
                            setEditing: { id, on in
                                if on { editingTripIDs.insert(id) } else { editingTripIDs.remove(id) }
                            },
                            removeTrip: { id in trips.removeAll { $0.id == id } },
                            commitTrip: { _ in /* no-op: already bound to trips */ }
                        ))
                }
            } // end Group
            .navigationTitle("MyTrip Planner")
            .toolbar {
                // Global temperature unit toggle (top-right)
                ToolbarItem(placement: .primaryAction) {
                    Picker("", selection: $appState.unit) {
                        Text("°F").tag(AppState.TempUnit.f)
                        Text("°C").tag(AppState.TempUnit.c)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .accessibilityLabel("Temperature Unit")
                } // end ToolbarItem

                // Inline "Add Card": create draft trip and start editing on its card
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let draft = Trip(
                            locationName: "",
                            date: Date(),
                            customName: nil,
                            isNameUserEdited: false,
                            city: nil,
                            latitude: nil,
                            longitude: nil,
                            images: []
                        )
                        trips.append(draft)
                        trips.sort { $0.date < $1.date }
                        editingTripIDs.insert(draft.id)
                    } label: { Image(systemName: "plus") }
                } // end ToolbarItem
            } // end .toolbar
        } // end NavigationStack
    } // end var body

    private var shouldShowTable: Bool {
        hSize == .regular || vSize == .compact
    } // end var shouldShowTable
} // end struct ContentView

// MARK: - Editing Controls Environment

/// Provides edit mode wiring for cards without tight coupling to the container.
/// end struct TripEditControls
struct TripEditControls {
    var isEditing: (UUID) -> Bool
    var setEditing: (UUID, Bool) -> Void
    var removeTrip: (UUID) -> Void
    var commitTrip: (UUID) -> Void
} // end struct TripEditControls

private struct TripEditControlsKey: EnvironmentKey {
    static let defaultValue = TripEditControls(
        isEditing: { _ in false },
        setEditing: { _, _ in },
        removeTrip: { _ in },
        commitTrip: { _ in }
    )
} // end struct TripEditControlsKey

extension EnvironmentValues {
    var tripEditControls: TripEditControls {
        get { self[TripEditControlsKey.self] }
        set { self[TripEditControlsKey.self] = newValue }
    }
} // end extension EnvironmentValues

