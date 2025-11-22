//
//  TripCardView.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/8/25.
//


// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import PhotosUI
import Photos

/// Single trip card with city/date, optional photo, and weather summary
struct TripCardView: View {
    let trip: Trip
    let isActive: Bool
    let onEdit: (Trip) -> Void
    let onDelete: (Trip) -> Void
    let onPhotoUpdate: (Trip, String?) -> Void

    @EnvironmentObject var app: AppState
    @State private var summary: String = "Fetching…"
    @State private var displayedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?

    /// True if the trip is today or in the future
    private var isTodayOrFuture: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: trip.date) >= today
    } // isTodayOrFuture

    /// Main body of the trip card
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // HEADER: city / date / coords + edit button
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.city.isEmpty ? "Unknown City" : trip.city)
                        .font(.title2.weight(.semibold))

                    Text(DF.med.string(from: trip.date))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let la = trip.latitude, let lo = trip.longitude {
                        Text(String(format: "%.4f, %.4f", la, lo))
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Button {
                    onEdit(trip)
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit trip")
            }

            // PHOTO AREA: hit-testing restricted strictly to this rectangle
            PhotosPicker(selection: $photoPickerItem,
                         matching: .images,
                         photoLibrary: .shared()) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )

                    if let image = displayedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 32, weight: .regular))
                                .foregroundStyle(.secondary)
                            Text("Add a photo from your library")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(height: 180)            // fixed, contained hit area
                .contentShape(Rectangle())     // taps only inside this rect
                .clipped()
            }
            .buttonStyle(.plain)
            .onChange(of: photoPickerItem) { _, newItem in
                Task { await handlePhotoSelection(newItem) }
            }

            Text(summary)
                .font(.callout)

            Spacer(minLength: 0)

            HStack {
                Button {
                    Task { await fetch() }
                } label: {
                    Label("Refresh Weather", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                }

                Spacer()

                Button(role: .destructive) {
                    onDelete(trip)
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Delete trip")
            }
            .font(.footnote)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: 360)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(isActive ? Color.accentColor.opacity(0.10)
                               : Color(.systemBackground))
                .shadow(radius: isActive ? 8 : 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .task {
            if isTodayOrFuture {
                await fetch()
            } else {
                summary = "Trip date has passed"
            }
            await loadExistingPhoto()
        }
        .onChange(of: app.isFahrenheit) { _, _ in
            Task {
                guard isTodayOrFuture else { return }
                await fetch()
            }
        }
    } // body

    /// Fetch weather and update summary text (only called for future/today trips)
    private func fetch() async {
        do {
            let (hi, lo, rain) = try await WeatherService.fetchDay(for: trip)
            let hiS = Units.tempStringC(hi, isF: app.isFahrenheit)
            let loS = Units.tempStringC(lo, isF: app.isFahrenheit)
            summary = "Hi \(hiS)  ·  Lo \(loS)  ·  Rain \(rain.map { "\($0)%" } ?? "—")"
        } catch {
            dlog("UI", "TripCard fetch ERR \(error)")
            summary = "No Weather @ Loc"
        }
    } // fetch

    /// Load an existing photo from Photos based on the trip's stored local identifier
    private func loadExistingPhoto() async {
        guard let id = trip.photoLocalIdentifier else {
            await MainActor.run { displayedImage = nil }
            return
        }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = assets.firstObject else {
            await MainActor.run { displayedImage = nil }
            return
        }

        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        await withCheckedContinuation { continuation in
            manager.requestImage(
                for: asset,
                targetSize: CGSize(width: 800, height: 800),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                DispatchQueue.main.async {
                    self.displayedImage = image
                    continuation.resume()
                }
            }
        }
    } // loadExistingPhoto

    /// Handle a new photo selection: show it immediately and store only the Photos local identifier
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        // Show the selected image immediately
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    self.displayedImage = uiImage
                }
            }
        } catch {
            dlog("UI", "Photo picker load ERR \(error)")
        }

        // Persist only the Photos local identifier for later reloads
        if let identifier = item.itemIdentifier {
            onPhotoUpdate(trip, identifier)
        }
    } // handlePhotoSelection
} // TripCardView
