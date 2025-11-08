// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import MapKit
import CoreLocation

/// Global state for remembering the last center used in the map picker
enum MapPickerState {
    /// Last center coordinate the user committed with "Use This Location"
    static var lastCenter: CLLocationCoordinate2D?
} // MapPickerState

/// Map picker that uses the map center as the selected coordinate (iOS 17+ style)
struct MapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var latitude: Double?
    @Binding var longitude: Double?

    @State private var position: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?

    /// Initialize with bindings; camera will be set in onAppear
    init(latitude: Binding<Double?>, longitude: Binding<Double?>) {
        _latitude = latitude
        _longitude = longitude
    } // MapPickerSheet.init

    /// Main body with center-crosshair map and confirm/cancel buttons
    var body: some View {
        NavigationStack {
            ZStack {
                Map(position: $position) { }
                    .mapControls {
                        MapUserLocationButton()
                        MapCompass()
                        MapPitchToggle()
                    }
                    .onMapCameraChange { ctx in
                        currentCenter = ctx.region.center
                    }
                    .overlay {
                        Image(systemName: "plus.circle.fill")
                            .font(.title)
                            .foregroundStyle(.tint)
                            .shadow(radius: 2)
                    }
                    .overlay(alignment: .bottom) {
                        Text(centerText())
                            .font(.footnote.monospaced())
                            .padding(8)
                            .background(.ultraThinMaterial,
                                        in: RoundedRectangle(cornerRadius: 10))
                            .padding(.bottom, 12)
                    }
            }
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Use This Location") {
                        useCenter()
                    }
                }
            }
            .onAppear(perform: configureInitialCamera)
        } // NavigationStack
    } // body

    // MARK: - Helpers

    /// Choose the starting camera based on: bound coords → lastMapCenter → default
    private func configureInitialCamera() {
        let startCoord: CLLocationCoordinate2D

        if let la = latitude, let lo = longitude {
            // Editing an existing trip: center on its saved location
            startCoord = CLLocationCoordinate2D(latitude: la, longitude: lo)
        } else if let last = MapPickerState.lastCenter {
            // No coords yet: use last map location if we have one
            startCoord = last
        } else {
            // Fallback somewhere reasonable
            startCoord = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060) // NYC
        }

        currentCenter = startCoord
        let region = MKCoordinateRegion(
            center: startCoord,
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
        position = .region(region)
    } // configureInitialCamera

    /// Commit the current center into the bindings and remember it globally
    private func useCenter() {
        let chosen: CLLocationCoordinate2D

        if let c = currentCenter {
            chosen = c
        } else if let la = latitude, let lo = longitude {
            chosen = CLLocationCoordinate2D(latitude: la, longitude: lo)
        } else if let last = MapPickerState.lastCenter {
            chosen = last
        } else {
            chosen = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        }

        latitude = chosen.latitude
        longitude = chosen.longitude
        MapPickerState.lastCenter = chosen

        dismiss()
    } // useCenter

    /// Bottom overlay text for the center coordinate
    private func centerText() -> String {
        if let c = currentCenter {
            return String(format: "Center  %.5f, %.5f", c.latitude, c.longitude)
        } else {
            return "Pan/zoom to position the crosshair"
        }
    } // centerText
} // MapPickerSheet

