// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import MapKit
import CoreLocation

/// Map picker that uses the map center as the selected coordinate (iOS 16/17+ compatible)
struct MapPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double?
    @Binding var longitude: Double?

    // iOS 17+: MapCameraPosition; iOS 16: MKCoordinateRegion fallback
    @State private var position: MapCameraPosition = .automatic
    @State private var currentCenter: CLLocationCoordinate2D?
    @State private var legacyRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 35.6804, longitude: 139.7690),
        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
    )

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if #available(iOS 17.0, *) {
                    Map(position: $position)
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                            MapPitchToggle()
                            MapScaleView()
                        }
                        .onMapCameraChange(frequency: .continuous) { ctx in
                            currentCenter = ctx.region.center
                        }
                        .overlay {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.tint)
                                .shadow(radius: 2)
                        }
                        .overlay(alignment: .bottom) {
                            Text(centerText17())
                                .font(.footnote.monospaced())
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .padding(.bottom, 12)
                        }
                        .onAppear { configureInitialCamera() }
                } else {
                    Map(coordinateRegion: $legacyRegion, interactionModes: [.all], showsUserLocation: true)
                        .mapControls {
                            MapUserLocationButton()
                            MapCompass()
                            MapPitchToggle()
                            MapScaleView()
                        }
                        .overlay {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                                .foregroundStyle(.tint)
                                .shadow(radius: 2)
                        }
                        .overlay(alignment: .bottom) {
                            Text(String(format: "Center  %.5f, %.5f", legacyRegion.center.latitude, legacyRegion.center.longitude))
                                .font(.footnote.monospaced())
                                .padding(8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                                .padding(.bottom, 12)
                        }
                        .onAppear {
                            if let la = latitude, let lo = longitude {
                                legacyRegion.center = .init(latitude: la, longitude: lo)
                                legacyRegion.span = .init(latitudeDelta: 0.2, longitudeDelta: 0.2)
                            }
                        }
                }

                HStack {
                    Button("Cancel") { dismiss() }
                    Spacer()
                    Button("Set Location") {
                        useCenter()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
                .padding(.bottom)
            } // VStack
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
        } // NavigationStack
    } // body

    /// Apply initial camera/region from existing bindings (iOS 17+)
    private func configureInitialCamera() {
        if let la = latitude, let lo = longitude {
            let c = CLLocationCoordinate2D(latitude: la, longitude: lo)
            currentCenter = c
            position = .region(.init(center: c, span: .init(latitudeDelta: 0.2, longitudeDelta: 0.2)))
        } else {
            let c = CLLocationCoordinate2D(latitude: 35.6804, longitude: 139.7690)
            currentCenter = c
            position = .region(.init(center: c, span: .init(latitudeDelta: 2.0, longitudeDelta: 2.0)))
        }
    } // configureInitialCamera

    /// Commit the current center to bindings and dismiss
    private func useCenter() {
        if #available(iOS 17.0, *) {
            guard let c = currentCenter else { dlog("MAP", "No center available (iOS17)"); return }
            latitude = c.latitude
            longitude = c.longitude
            dlog("MAP", "Picked center \(c.latitude), \(c.longitude)")
            dismiss()
        } else {
            latitude = legacyRegion.center.latitude
            longitude = legacyRegion.center.longitude
            dlog("MAP", "Picked center \(legacyRegion.center.latitude), \(legacyRegion.center.longitude)")
            dismiss()
        }
    } // useCenter

    /// Bottom overlay text (iOS 17+)
    private func centerText17() -> String {
        if let c = currentCenter {
            return String(format: "Center  %.5f, %.5f", c.latitude, c.longitude)
        } else {
            return "Pan/zoom to position the crosshair"
        }
    } // centerText17
} // MapPickerSheet

