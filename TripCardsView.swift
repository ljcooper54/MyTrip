// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// Horizontally swipeable cards of trips for compact portrait iPhone
struct TripCardsView: View {
    let trips: [Trip]
    let onEdit: (Trip) -> Void
    let onDelete: (Trip) -> Void
    let onPhotoUpdate: (Trip, String?) -> Void

    @State private var selection: Int = 0

    /// Trips ordered by date ascending so the carousel is chronological
    private var orderedTrips: [Trip] {
        trips.sorted { $0.date < $1.date }
    } // orderedTrips

    /// Main body showing either empty card or a page-style TabView of cards
    var body: some View {
        if orderedTrips.isEmpty {
            EmptyTripCard()
                .padding(.horizontal, 24)
        } else {
            GeometryReader { geo in
                ZStack {
                    // Main card carousel
                    TabView(selection: $selection) {
                        ForEach(Array(orderedTrips.enumerated()), id: \.element.id) { index, trip in
                            TripCardView(
                                trip: trip,
                                isActive: index == selection,
                                onEdit: onEdit,
                                onDelete: onDelete,
                                onPhotoUpdate: onPhotoUpdate
                            )
                            // Make card a bit narrower than the full width
                            .frame(width: geo.size.width * 0.80)
                            .padding(.horizontal, geo.size.width * 0.10)
                            .tag(index)
                        } // ForEach
                    } // TabView
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    // Non-overlapping affordances: chevron hints at left/right edges
                    HStack {
                        if selection > 0 {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.tint)
                                .opacity(0.9)
                                .padding(.leading, 8)
                        }

                        Spacer()

                        if selection < orderedTrips.count - 1 {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.tint)
                                .opacity(0.9)
                                .padding(.trailing, 8)
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 400)
            .onAppear {
                // Start on today's (or next upcoming) card if possible
                let today = Calendar.current.startOfDay(for: Date())
                if let idx = orderedTrips.firstIndex(where: { trip in
                    Calendar.current.startOfDay(for: trip.date) >= today
                }) {
                    selection = idx
                } else {
                    // No future/today trips? show the last one
                    selection = orderedTrips.count - 1
                }
            }
        }
    } // body
} // TripCardsView

/// Empty-state card shown when there are no trips
struct EmptyTripCard: View {
    /// Main body for the empty-state card
    var body: some View {
        VStack(spacing: 16) {
            Text("No trips yet")
                .font(.title2.weight(.semibold))

            Text("Click + to enter a location and date")
                .font(.body)
                .multilineTextAlignment(.center)

            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                .frame(height: 180)
                .overlay {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28, weight: .regular))
                            .foregroundStyle(.secondary)
                        Text("Your trip photo could go here")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: 360)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.background)
                .shadow(radius: 6)
        )
    } // body
} // EmptyTripCard

