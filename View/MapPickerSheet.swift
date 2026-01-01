// Copyright 2025 H2so4 Consulting LLC
// File: View/MapPickerSheet.swift

import SwiftUI
import MapKit
import CoreLocation
import Foundation

/// Crosshair-centered picker: move the map; the **center** is your selection.
/// We track the center via `.onMapCameraChange` and use MapKit search for labels.
/// MapPickerSheet
@MainActor
struct MapPickerSheet: View {

    // MARK: - Inputs

    /// Optional starting coordinate (e.g., from the current Trip).
    let initial: CLLocationCoordinate2D?

    /// Called when the user taps "Done" with the chosen coordinate and its label.
    let onPick: (CLLocationCoordinate2D, String) -> Void

    // MARK: - Static state (shared across uses)

    /// Last-used coordinate so new cards can start where the user last picked.
    private static var lastUsedCoordinate: CLLocationCoordinate2D?

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @State private var centerCoord: CLLocationCoordinate2D? = nil
    @State private var pendingName: String = "Unknown location"
    @State private var isLookingUpName: Bool = false
    @State private var lookupTask: Task<Void, Never>? = nil
    @State private var lastLookupCoord: CLLocationCoordinate2D? = nil

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                mapView

                // Crosshair in the middle of the map
                CrosshairView()

                // Bottom label showing the resolved name
                VStack {
                    Spacer()
                    HStack(spacing: 6) {
                        if isLookingUpName {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                        Text(pendingName)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.thinMaterial)
                    .clipShape(Capsule())
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Choose Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { confirmSelection() }
                        .disabled(centerCoord == nil)
                }
            }
        }
    } // end var body

    // MARK: - Map view

    @ViewBuilder
    private var mapView: some View {
        Map(position: $camera)
            .mapStyle(.standard)
            .mapControls {
                MapCompass()
                MapPitchToggle()
                MapScaleView()
            }
            .onAppear {
                configureInitialCamera()
            }
            .onMapCameraChange { ctx in
                let center = ctx.region.center
                centerCoord = center
                scheduleLookup(for: center)
            }
    } // end var mapView

    // MARK: - Helpers

    /// Sets the starting camera region using either `initial` or `lastUsedCoordinate`.
    private func configureInitialCamera() {
        if let start = initial ?? MapPickerSheet.lastUsedCoordinate ?? GeocoderService.shared.lastResolvedCoordinate {
            let span = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            camera = .region(MKCoordinateRegion(center: start, span: span))
            centerCoord = start
            scheduleLookup(for: start)
        } else {
            // Leave camera as .automatic; center/name will be updated as soon as Map reports back.
        }
    } // end func configureInitialCamera

    /// Confirms the current center coordinate and calls `onPick`.
    private func confirmSelection() {
        guard let center = centerCoord else {
            dismiss()
            return
        }
        MapPickerSheet.lastUsedCoordinate = center
        onPick(center, pendingName)
        dismiss()
    } // end func confirmSelection

    /// Uses ReverseGeocoderService (MapKit-based) to get a friendly name.
    private func updatePreviewName(for coord: CLLocationCoordinate2D) async {
        isLookingUpName = true
        defer { isLookingUpName = false }
        do {
            let label = try await ReverseGeocoderService.shared.nearestPlaceName(near: coord)
            pendingName = label
        } catch {
            pendingName = "Unknown location"
            print("[ReverseGeocoder] lookup failed: \(error)")
        }
    } // end func updatePreviewName

    private func scheduleLookup(for coord: CLLocationCoordinate2D) {
        if let last = lastLookupCoord,
           abs(last.latitude - coord.latitude) < 0.0005,
           abs(last.longitude - coord.longitude) < 0.0005 {
            return
        }
        lastLookupCoord = coord
        lookupTask?.cancel()
        lookupTask = Task { @MainActor in
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            guard !Task.isCancelled else { return }
            await updatePreviewName(for: coord)
        }
    } // end func scheduleLookup
} // end struct MapPickerSheet

/// Simple crosshair drawing.
/// CrosshairView
private struct CrosshairView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .frame(width: 24, height: 1)
                .foregroundStyle(.primary.opacity(0.8))
            Rectangle()
                .frame(width: 1, height: 24)
                .foregroundStyle(.primary.opacity(0.8))
            Circle()
                .frame(width: 4, height: 4)
                .foregroundStyle(.red)
        } // end ZStack
        .accessibilityHidden(true)
    } // end var body
} // end struct CrosshairView
