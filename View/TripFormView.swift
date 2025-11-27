// Copyright H2so4 Consulting LLC 2025
// File: View/TripFormView.swift

import SwiftUI

/// Add-trip form aligned with the current `Trip` initializer (no notes).
/// end struct TripFormView
struct TripFormView: View {

    // MARK: - Inputs

    var onSave: (Trip) -> Void

    // MARK: - Environment

    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var locationName: String = ""
    @State private var city: String = ""
    @State private var date: Date = Date()

    // MARK: - Body

    var body: some View {
        Form {
            Section("Where") {
                TextField("Location name (required)", text: $locationName)
                TextField("City (optional)", text: $city)
            } // end Section(Where)

            Section("When") {
                DatePicker("Date", selection: $date, displayedComponents: .date)
            } // end Section(When)
        } // end Form
        .navigationTitle("New Stop")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            } // end ToolbarItem

            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(locationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } // end ToolbarItem
        } // end .toolbar
    } // end var body

    // MARK: - Actions

    /// Builds a `Trip` using current form values and calls `onSave`.
    /// end func save()
    private func save() {
        let trimmedLocation = locationName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let newTrip = Trip(
            locationName: trimmedLocation,
            date: date,
            customName: nil,
            isNameUserEdited: false,
            city: trimmedCity.isEmpty ? nil : trimmedCity,
            latitude: nil,
            longitude: nil,
            images: []
        ) // end Trip init

        onSave(newTrip)
        dismiss()
    } // end func save()
} // end struct TripFormView


