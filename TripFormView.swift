// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import Foundation

/// Trip editor with live onChange weather and auto reverse-geocode
struct TripFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var app: AppState
    @EnvironmentObject var store: TripStore
    @State var trip: Trip
    let onSave: (Trip) -> Void

    @State private var city: String = ""
    @State private var date: Date = Date()
    @State private var lat: Double?
    @State private var lon: Double?
    @State private var status: String = ""
    @State private var showMap = false
    @State private var fetchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                destinationSection
                coordinatesSection
                if !status.isEmpty { weatherSection }
            }
            .navigationTitle("Trip")
            .sheet(isPresented: $showMap, onDismiss: {
                Task {
                    // Force-update city name based on the map location just chosen
                    await updateCityFromCoords(force: true)
                }
            }) {
                MapPickerSheet(latitude: $lat, longitude: $lon)
            }

            .toolbar { toolbarContent }
            .onAppear(perform: onAppear)
            .onChangeCompat(of: city) { _ in triggerFetch() }
            .onChangeCompat(of: date) { _ in triggerFetch() }
            .onChangeCompat(of: lat)  { _ in handleCoordChange() }
            .onChangeCompat(of: lon)  { _ in handleCoordChange() }

        } // NavigationStack
    } // body

    // MARK: - Sections

    private var destinationSection: some View {
        Section("Destination") {
            TextField("City", text: $city)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
            DatePicker("Date", selection: $date, displayedComponents: .date)
        }
    } // destinationSection

    private var coordinatesSection: some View {
        Section("Coordinates") {
            HStack {
                Text(coordLabel())
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Set Location", action: setLocationTapped)
            }
            if lat != nil || lon != nil {
                Button("Clear Coordinates") { lat = nil; lon = nil }
                    .foregroundStyle(.red)
            }
        }
    } // coordinatesSection

    private var weatherSection: some View {
        Section("Weather") { Text(status).font(.callout) }
    } // weatherSection

    // MARK: - Toolbar

    private var toolbarContent: some ToolbarContent {
        Group {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", action: saveTapped)
                    .disabled(isSaveDisabled())
            }
        }
    } // toolbarContent

    // MARK: - Actions

    private func onAppear() {
        city = trip.city
        date = trip.date
        lat = trip.latitude
        lon = trip.longitude
        triggerFetch()
    } // onAppear

    private func setLocationTapped() {
        if lat == nil || lon == nil {
            if let (la, lo) = store.lastCoordinate() {
                lat = la; lon = lo
            } else {
                // West Concord, MA, USA (approx)
                lat = 42.4593; lon = -71.4006
            }
        }
        showMap = true
    } // setLocationTapped

    private func saveTapped() {
        var t = trip
        t.city = city.trimmingCharacters(in: .whitespacesAndNewlines)
        t.date = date
        t.latitude = lat
        t.longitude = lon
        onSave(t)
        dismiss()
    } // saveTapped

    private func handleCoordChange() {
        Task {
            Task { await updateCityFromCoords(force: false) }

            triggerFetch()
        }
    } // handleCoordChange

    // MARK: - Helpers

    private func isSaveDisabled() -> Bool {
        let hasCity = !city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasCoords = (lat != nil && lon != nil)
        return !(hasCity || hasCoords)
    } // isSaveDisabled

    private func coordLabel() -> String {
        if let la = lat, let lo = lon {
            return String(format: "Lat %.5f  Lon %.5f", la, lo)
        }
        return "No location selected"
    } // coordLabel

    /// Launch/cancel a live fetch; sets "No Weather @ Loc" on failure
    private func triggerFetch() {
        fetchTask?.cancel()
        fetchTask = Task { @MainActor in
            let cleaned = city.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty || (lat != nil && lon != nil) else { status = ""; return }
            var t = trip; t.city = cleaned; t.date = date; t.latitude = lat; t.longitude = lon
            do {
                let (hi, lo, rain) = try await WeatherService.fetchDay(for: t)
                let hiS = Units.tempStringC(hi, isF: app.isFahrenheit)
                let loS = Units.tempStringC(lo, isF: app.isFahrenheit)
                status = "Hi \(hiS) · Lo \(loS) · Rain \(rain.map { "\($0)%" } ?? "—")"
            } catch {
                dlog("UI", "Live fetch ERR \(error)")
                status = "No Weather @ Loc"
            }
        }
    } // triggerFetch

    /// Reverse-geocode the current coordinates and update the city.
    /// - Parameter force: if true, update even if city is non-empty (used after map pick)
    private func updateCityFromCoords(force: Bool) async {
        let cleaned = city.trimmingCharacters(in: .whitespacesAndNewlines)
        if !force && !cleaned.isEmpty { return }
        guard let la = lat, let lo = lon else { return }

        if let name = await ReverseGeocoderService.name(lat: la, lon: lo) {
            await MainActor.run { city = name }
            dlog("MAP", "Reverse geocoded city: \(name)")
        }
    } // updateCityFromCoords
} // TripFormView




