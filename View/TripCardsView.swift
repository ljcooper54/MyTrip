// Copyright 2025 H2so4 Consulting LLC
// File: View/TripCardsView.swift

import SwiftUI
import CoreLocation

/// TripCardsView shows the horizontally swipable deck of trip cards,
/// with red arrows as swipe affordances and delete + auto-naming support.
/// TripCardsView
struct TripCardsView: View {
    /// Binding into the array of trips owned by PlannerView.
    @Binding var trips: [Trip]

    /// The index of the currently visible card.
    @State private var selectedIndex: Int = 0

    /// Last date the user interacted with; used as the default for new cards.
    @State private var lastUsedDate: Date = Date()

    /// Index pending deletion (for confirmation alert).
    @State private var pendingDeleteIndex: Int? = nil

    var body: some View {
        VStack(spacing: 12) {
            // Top bar with "+" that adds a blank card *in place*.
            HStack {
                Spacer()
                Button {
                    addBlankTripAndSelect()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .imageScale(.large)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add Trip Card")
            }
            .padding(.horizontal)

            GeometryReader { geo in
                ZStack {
                    if !trips.isEmpty {
                        TabView(selection: $selectedIndex) {
                            ForEach(Array(trips.enumerated()), id: \.element.id) { idx, _ in
                                TripCardView(
                                    place: Binding(
                                        get: { trips[idx].place },
                                        set: { trips[idx].place = $0 }
                                    ),
                                    date: Binding(
                                        get: { trips[idx].date },
                                        set: { trips[idx].date = $0 }
                                    ),
                                    coordinate: Binding(
                                        get: { trips[idx].coordinate },
                                        set: { trips[idx].coordinate = $0 }
                                    ),
                                    images: Binding(
                                        get: { trips[idx].images },
                                        set: { trips[idx].images = $0 }
                                    ),
                                    onPickLocation: {
                                        // No-op hook for now; all work is handled inside TripCardView.
                                    },
                                    onAddPhoto: {
                                        // No-op hook for now; all work is handled inside TripCardView.
                                    },
                                    onSuggestPhoto: {
                                        // Suggest logic lives inside TripCardView; nothing extra here.
                                    },
                                    onDeleteTapped: {
                                        pendingDeleteIndex = idx
                                    },
                                    onCoordinateSetNeedsName: { coord in
                                        Task {
                                            await fillPlaceNameIfNeeded(
                                                forIndex: idx,
                                                coordinate: coord
                                            )
                                        }
                                    }
                                )
                                .frame(width: geo.size.width * 0.9)
                                .tag(idx)
                            } // end ForEach
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))

                        // Red arrows just outside the card at the bottom as swipe affordances.
                        HStack {
                            if hasPrevious {
                                arrowView(systemName: "chevron.left")
                                    .onTapGesture {
                                        move(-1)
                                    }
                            } else {
                                Spacer().frame(width: 32)
                            }

                            Spacer()

                            if hasNext {
                                arrowView(systemName: "chevron.right")
                                    .onTapGesture {
                                        move(1)
                                    }
                            } else {
                                Spacer().frame(width: 32)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 4)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    } else {
                        Text("Tap + to add your first trip.")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 380)
        }
        .onAppear {
            if let latest = trips.last?.date ?? trips.map(\.date).max() {
                lastUsedDate = latest
            }
        }
        .onChange(of: trips) { oldValue, newValue in
            // Track the most recently edited/added date so new cards inherit it.
            if let changed = newValue.enumerated().first(where: { idx, trip in
                idx >= oldValue.count || oldValue[idx].date != trip.date
            }) {
                lastUsedDate = changed.element.date
            } else if let latest = newValue.last?.date ?? newValue.map(\.date).max() {
                lastUsedDate = latest
            }
        }
        .alert("Delete this trip?", isPresented: Binding(
            get: { pendingDeleteIndex != nil },
            set: { newValue in
                if !newValue { pendingDeleteIndex = nil }
            }
        )) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let index = pendingDeleteIndex {
                    deleteTrip(at: index)
                }
            }
        } message: {
            Text("This action cannot be undone.")
        }
    } // end var body  // TripCardsView

    /// Red circular arrow shown just outside the card.
    private func arrowView(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3.weight(.bold))
            .foregroundColor(.red)
            .padding(6)
            .background(
                Circle()
                    .strokeBorder(Color.red, lineWidth: 1.5)
                    .background(Circle().fill(Color(.systemBackground)))
            )
            .offset(y: 12) // sit slightly below the card edge
    } // end func arrowView

    /// Whether there is a previous card to the left.
    private var hasPrevious: Bool {
        selectedIndex > 0 && selectedIndex < trips.count
    } // end var hasPrevious

    /// Whether there is a next card to the right.
    private var hasNext: Bool {
        !trips.isEmpty && selectedIndex < trips.count - 1
    } // end var hasNext

    /// Moves selection left (-1) or right (+1) if possible.
    private func move(_ delta: Int) {
        let newIndex = selectedIndex + delta
        guard newIndex >= 0 && newIndex < trips.count else { return }
        selectedIndex = newIndex
    } // end func move

    /// Adds a new blank trip and selects it.
    private func addBlankTripAndSelect() {
        var newTrip = Trip.blank(at: lastUsedDate)
        newTrip.images.removeAll()
        trips.append(newTrip)
        withAnimation { selectedIndex = max(0, trips.count - 1) }
    } // end func addBlankTripAndSelect

    /// Deletes a trip at the given index.
    private func deleteTrip(at index: Int) {
        guard index >= 0 && index < trips.count else { return }
        trips.remove(at: index)
        if trips.isEmpty {
            selectedIndex = 0
        } else {
            selectedIndex = min(index, trips.count - 1)
        }
    } // end func deleteTrip

    /// If the place name is empty for a given card, look up the nearest "significant"
    /// place name using MapKit's `ReverseGeocoderService` (no deprecated CLGeocoder APIs).
    @MainActor
    private func fillPlaceNameIfNeeded(forIndex index: Int, coordinate: CLLocationCoordinate2D) async {
        guard index >= 0 && index < trips.count else { return }

        // If the user has already typed something, do nothing.
        if !trips[index].place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        do {
            let label = try await ReverseGeocoderService.shared.nearestPlaceName(near: coordinate)
            trips[index].place = label
        } catch {
            // If lookup fails, we simply leave the place blank.
            // You can add logging if desired.
            print("[ReverseGeocoder] Failed to name coordinate: \(error)")
        }
    } // end func fillPlaceNameIfNeeded
} // end struct TripCardsView

