// Copyright H2so4 Consulting LLC 2025
// File: View/MapPickerSheet.swift

import SwiftUI
import MapKit
import CoreLocation

/// Crosshair-centered picker: move the map; the **center** is your selection.
/// We track the center via `.onMapCameraChange` to avoid snapshot conversions.
/// end struct MapPickerSheet
struct MapPickerSheet: View {

    // MARK: - Inputs

    var initial: CLLocationCoordinate2D?
    var onPick: (CLLocationCoordinate2D, String) -> Void

    // MARK: - State

    @Environment(\.dismiss) private var dismiss
    @State private var camera: MapCameraPosition = .automatic
    @State private var centerCoord: CLLocationCoordinate2D? = nil
    @State private var pendingName: String = "Unknown location"

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $camera)
                    .onAppear {
                        if let c = initial {
                            camera = .region(MKCoordinateRegion(center: c, span: .init(latitudeDelta: 0.12, longitudeDelta: 0.12)))
                            centerCoord = c
                            Task { await updatePreviewName(c) }
                        }
                    } // end .onAppear
                    .onMapCameraChange { ctx in
                        // Keep center coordinate up to date as user pans/zooms.
                        centerCoord = ctx.region.center
                    } // end .onMapCameraChange

                CrosshairView()
                    .frame(width: 40, height: 40)
                    .allowsHitTesting(false)

                VStack {
                    Spacer()
                    Text(pendingName)
                        .font(.footnote)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.bottom, 16)
                        .allowsHitTesting(false)
                } // end VStack
            } // end ZStack
            .navigationTitle("Pick Location")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                } // end ToolbarItem
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use") {
                        guard let coord = centerCoord else { return }
                        Task {
                            let finalName = (try? await ReverseGeocoderService.shared.nearestPlaceName(near: coord)) ?? pendingName
                            onPick(coord, finalName)
                            dismiss()
                        }
                    }
                } // end ToolbarItem
            } // end .toolbar
        } // end NavigationStack
    } // end var body

    // MARK: - Helpers

    private func updatePreviewName(_ coord: CLLocationCoordinate2D) async {
        if let name = try? await ReverseGeocoderService.shared.nearestPlaceName(near: coord) {
            pendingName = name
        } else {
            pendingName = "Unknown location"
        }
    } // end func updatePreviewName(_:)
} // end struct MapPickerSheet

/// Simple crosshair drawing.
/// end struct CrosshairView
private struct CrosshairView: View {
    var body: some View {
        ZStack {
            Rectangle().frame(width: 24, height: 1).foregroundStyle(.primary.opacity(0.8))
            Rectangle().frame(width: 1, height: 24).foregroundStyle(.primary.opacity(0.8))
            Circle().frame(width: 4, height: 4).foregroundStyle(.red)
        } // end ZStack
        .accessibilityHidden(true)
    } // end var body
} // end struct CrosshairView

