// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
// =======================================
// File: View/PlannerView.swift
// (Ensure it uses TripCardsView with @State var trips: [Trip])
// =======================================

import SwiftUI

struct PlannerView: View {
    @State private var trips: [Trip] = []

    var body: some View {
        NavigationStack {
            TripCardsView(trips: $trips)
                .navigationTitle("MyTrip Planner")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            TripFormView(onSave: { newTrip in
                                trips.append(newTrip)
                                trips.sort { $0.date < $1.date }
                            })
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
        }
    }

} // PlannerView

