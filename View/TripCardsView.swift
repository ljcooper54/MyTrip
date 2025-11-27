// Copyright H2so4 Consulting LLC 2025
// File: View/TripCardsView.swift

import SwiftUI

/// Carousel of trip cards with swipe affordance, anchored on today's date.
/// In compact/portrait this is the primary layout.
/// end struct TripCardsView
struct TripCardsView: View {

    // MARK: - Inputs

    @EnvironmentObject private var app: AppState
    @Binding var trips: [Trip]

    // MARK: - State

    @State private var startIndex: Int = 0

    // MARK: - Body

    var body: some View {
        TabView(selection: $startIndex) {
            ForEach(Array(trips.enumerated()), id: \.element.id) { idx, _ in
                TripCardView(trip: binding(forIndex: idx))
                    .environmentObject(app)
                    .padding(.horizontal)
                    .tag(idx)
            } // end ForEach
        } // end TabView
        .tabViewStyle(.page(indexDisplayMode: .always))
        .onAppear {
            startIndex = indexForToday()
        } // end .onAppear
    } // end var body

    private func indexForToday() -> Int {
        let today = Calendar.current.startOfDay(for: Date())
        if let idx = trips.firstIndex(where: { Calendar.current.startOfDay(for: $0.date) >= today }) { return idx }
        return max(0, trips.count - 1)
    } // end func indexForToday

    private func binding(forIndex idx: Int) -> Binding<Trip> {
        return Binding(
            get: { trips[idx] },
            set: { trips[idx] = $0 }
        )
    } // end func binding(forIndex:)
} // end struct TripCardsView

