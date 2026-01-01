// Copyright 2025 H2so4 Consulting LLC
// File: View/TripCardView.swift

import SwiftUI
import CoreLocation
import PhotosUI
import UIKit

/// TripCardView shows one trip as a card, with in-place editing for
/// place, date, pick location, add/suggest photo, weather, and a trash-can delete button.
/// TripCardView
struct TripCardView: View {
    // MARK: - Bindings into the model

    /// Place / title text for this trip, bound to `Trip.place`.
    @Binding var place: String

    /// Date for this trip, bound to `Trip.date`.
    @Binding var date: Date

    /// Optional coordinate for this trip, bound to `Trip.coordinate`.
    @Binding var coordinate: CLLocationCoordinate2D?

    /// Array of images for this trip, bound to `Trip.images`.
    @Binding var images: [TripImage]

    // MARK: - Callbacks to the parent

    /// Called when the user taps "Pick Location". Parent can hook into this if needed.
    var onPickLocation: () -> Void

    /// Called when the user taps "Add Photo". Parent can hook into this if needed.
    var onAddPhoto: () -> Void

    /// Called when the user taps "Suggest Photo". Parent can hook into this if needed.
    var onSuggestPhoto: () -> Void

    /// Called when the trash-can icon is tapped (confirmation handled by parent).
    var onDeleteTapped: () -> Void

    /// Optional: parent hook in case you still want to do extra work on coordinate changes.
    var onCoordinateSetNeedsName: (CLLocationCoordinate2D) -> Void = { _ in }

    // MARK: - Local UI state

    @State private var showLocationPicker = false
    @State private var showPhotoPicker = false
    @State private var isSuggesting = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoError: String? = nil

    @State private var todaysWeather: DailyWeather?
    @State private var isLoadingWeather = false
    @State private var weatherFetchTask: Task<Void, Never>? = nil
    @State private var weatherMessage: String? = nil

    /// Used so that tapping Suggest / buttons can end editing cleanly.
    @FocusState private var placeFieldFocused: Bool

    /// Convenience: primary image to show on the card (most recent).
    private var primaryImage: TripImage? {
        images.last
    } // end var primaryImage

    var body: some View {
        VStack(spacing: 12) {
            // Place + date row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TextField("Place", text: $place)
                    .textFieldStyle(.roundedBorder)
                    .focused($placeFieldFocused)
                    .submitLabel(.done)

                DatePicker(
                    "",
                    selection: $date,
                    displayedComponents: [.date]
                )
                .labelsHidden()
            }

            // Photo (if any)
            if let primaryImage {
                imageView(for: primaryImage)
            }

            // Buttons row: Pick location / Add photo / Suggest photo
            HStack(spacing: 10) {
                Button {
                    placeFieldFocused = false
                    showLocationPicker = true
                    onPickLocation()
                } label: {
                    Label("Map", systemImage: "mappin.and.ellipse")
                }

                Button {
                    placeFieldFocused = false
                    showPhotoPicker = true
                    onAddPhoto()
                } label: {
                    Label("Photo", systemImage: "photo")
                }

                Button {
                    placeFieldFocused = false
                    isSuggesting = true
                    Task {
                        await suggestPhotoForCurrentTrip()
                    }
                } label: {
                    if isSuggesting {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Label("Suggest", systemImage: "sparkles")
                    }
                }
                .disabled(isSuggesting)
            }
            .buttonStyle(.borderedProminent)

            Spacer(minLength: 4)

            // Bottom: weather strip + coordinate + trash.
            VStack(spacing: 4) {
                weatherStrip
                coordinateRow
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .sheet(isPresented: $showLocationPicker) {
            // Uses MapPickerSheet(initial:onPick:) with (coordinate, name) closure.
            MapPickerSheet(initial: coordinate) { newCoordinate, name in
                coordinate = newCoordinate

                let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    // If the user hasn't typed a name yet, use the provided human-friendly name.
                    place = name
                }

                // Optional additional hook for parent if desired.
                onCoordinateSetNeedsName(newCoordinate)
                Task { await queueWeatherLoad(debounce: false) }
            }
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .task(id: selectedPhotoItem) {
            await handleSelectedPhotoItem()
        }
        // Load / refresh weather when coordinate or date (or name) changes.
        .task(id: weatherTaskID) {
            await queueWeatherLoad(debounce: true)
        }
    } // end var body

    // MARK: - Subviews

    /// Weather strip view.
    @ViewBuilder
    private var weatherStrip: some View {
        if let weather = todaysWeather {
            HStack {
                Text("\(Int(round(weather.high)))° / \(Int(round(weather.low)))°")
                Text("•")
                Text("Rain \(Int(round(weather.pop * 100)))%")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else if let message = weatherMessage {
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if isLoadingWeather {
            HStack {
                ProgressView()
                Text("Loading weather…")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    } // end var weatherStrip

    /// Coordinate + trash row.
    @ViewBuilder
    private var coordinateRow: some View {
        HStack {
            if let coordinate {
                let lat = String(format: "%.3f", coordinate.latitude)
                let lon = String(format: "%.3f", coordinate.longitude)
                Text("\(lat), \(lon)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if place.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("No location selected")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(role: .destructive) {
                onDeleteTapped()
            } label: {
                Image(systemName: "trash")
                    .font(.title3)
            }
            .accessibilityLabel("Delete Trip")
        }
    } // end var coordinateRow

    /// Unique ID for weather-loading task based on coordinate + date + place text.
    private var weatherTaskID: String {
        let coordPart: String
        if let c = coordinate {
            coordPart = "\(c.latitude.rounded())_\(c.longitude.rounded())"
        } else {
            coordPart = "noCoord"
        }
        let day = Calendar.current.startOfDay(for: date)
        let namePart = place.trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(coordPart)_\(day.timeIntervalSince1970)_\(namePart)"
    } // end var weatherTaskID

    /// Builds a SwiftUI image view for a TripImage, preferring local file over remote URL.
    @ViewBuilder
    private func imageView(for img: TripImage) -> some View {
        if let fileURL = img.fileURL,
           let data = try? Data(contentsOf: fileURL),
           let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: 180)
                .clipped()
                .cornerRadius(10)
        } else if let remote = img.remoteURL {
            AsyncImage(url: remote) { phase in
                switch phase {
                case .empty:
                    ProgressView()
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color.gray.opacity(0.2)
                @unknown default:
                    Color.gray.opacity(0.2)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: 180)
            .clipped()
            .cornerRadius(10)
        }
    } // end func imageView

    // MARK: - Photo & OpenAI helpers

    /// Handles the selected photo from PhotosPicker by saving it via ImageStore
    /// and appending a TripImage to `images`.
    @MainActor
    private func handleSelectedPhotoItem() async {
        guard let item = selectedPhotoItem else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                if let saved = try? ImageStore.shared.saveImage(data, source: .user) {
                    let tripImage = TripImage(
                        id: saved.id,
                        fileURL: saved.fileURL,
                        remoteURL: nil,
                        createdAt: saved.createdAt,
                        source: .user
                    )
                    images.append(tripImage)
                }
            }
        } catch {
            print("[Photos] Failed to load selected image: \(error)")
        }
    } // end func handleSelectedPhotoItem

    /// Suggests a photo for the current trip using OpenAIPhotoLinkService and appends it.
    @MainActor
    private func suggestPhotoForCurrentTrip() async {
        defer { isSuggesting = false }
        let name = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let query: String
        if name.isEmpty || name == "Unknown location" {
            if let coordinate {
                query = String(
                    format: "location at %.3f, %.3f",
                    coordinate.latitude,
                    coordinate.longitude
                )
            } else {
                query = "a notable travel destination"
            }
        } else {
            query = name
        }
        do {
            let img = try await OpenAIPhotoLinkService().suggestPhoto(for: query)
            images.append(img)
            onSuggestPhoto()
            photoError = nil
        } catch {
            print("[OpenAI] Suggest photo failed: \(error)")
            photoError = "We couldn't fetch a suggested photo right now. Please try again."
        }
    } // end func suggestPhotoForCurrentTrip

    // MARK: - Weather

    /// Debounced weather loader that avoids firing until the user pauses typing.
    @MainActor
    private func queueWeatherLoad(debounce: Bool) async {
        weatherFetchTask?.cancel()
        weatherFetchTask = Task { @MainActor in
            if debounce {
                do { try await Task.sleep(for: .milliseconds(650)) } catch { return }
            }
            guard !Task.isCancelled else { return }
            await loadWeatherIfPossible()
        }
    } // end func queueWeatherLoad

    /// Loads weather for this card:
    /// - If coordinate exists, WeatherService will use it.
    /// - Otherwise, it will geocode the typed name (customName) using MapKit.
    @MainActor
    private func loadWeatherIfPossible() async {
        isLoadingWeather = true
        weatherMessage = nil
        defer { isLoadingWeather = false }

        // Build a Trip value for WeatherService; it only cares about
        // coordinate + date and name for geocoding.
        let trimmedName = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let tempTrip = Trip(
            id: UUID(),
            locationName: trimmedName.isEmpty ? "Unknown" : trimmedName,
            date: date,
            customName: trimmedName.isEmpty ? nil : trimmedName,
            isNameUserEdited: !trimmedName.isEmpty,
            city: nil,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            images: images
        )

        do {
            let svc = WeatherService()
            let unit: TemperatureUnit = .f  // Change to .c if you prefer Celsius.
            let forecast = try await svc.forecastForTripDate(for: tempTrip, unit: unit)
            todaysWeather = forecast
            weatherMessage = forecast == nil ? "No Weather" : nil
        } catch {
            todaysWeather = nil
            weatherMessage = "Weather unavailable"
            print("[Weather] Failed to load forecast: \(error)")
        }
    } // end func loadWeatherIfPossible
} // end struct TripCardView
