// Copyright 2025 H2so4 Consulting LLC
import SwiftUI
import PhotosUI
import Photos
import Combine

/// Horizontally swipeable cards of trips for compact portrait iPhone
struct TripCardsView: View {
    let trips: [Trip]
    let onEdit: (Trip) -> Void
    let onDelete: (Trip) -> Void
    let onPhotoUpdate: (Trip, String?) -> Void

    @State private var selection: Int = 0

    /// Main body showing either empty card or a page-style TabView of cards
    var body: some View {
        if trips.isEmpty {
            EmptyTripCard()
                .padding(.horizontal, 24)
        } else {
            GeometryReader { geo in
                VStack(spacing: 8) {
                    TabView(selection: $selection) {
                        ForEach(Array(trips.enumerated()), id: \.element.id) { index, trip in
                            TripCardView(
                                trip: trip,
                                onEdit: onEdit,
                                onDelete: onDelete,
                                onPhotoUpdate: onPhotoUpdate
                            )
                            .frame(width: geo.size.width * 0.82)
                            .padding(.horizontal, geo.size.width * 0.09)
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))

                    if trips.count > 1 {
                        Text("Swipe left or right to see other trips")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
            }
            .frame(height: 400)
        }
    } // body
} // TripCardsView

/// Single trip card with city/date, optional photo, weather summary, and extension footer
struct TripCardView: View {
    let trip: Trip
    let onEdit: (Trip) -> Void
    let onDelete: (Trip) -> Void
    let onPhotoUpdate: (Trip, String?) -> Void

    @EnvironmentObject var app: AppState
    @EnvironmentObject var extensions: TripExtensionRegistry
    @State private var summary: String = "Fetching…"
    @State private var displayedImage: UIImage?
    @State private var photoPickerItem: PhotosPickerItem?

    /// True if the trip is today or in the future
    private var isTodayOrFuture: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: trip.date) >= today
    }

    /// Main body of the trip card
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
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

            PhotosPicker(
                selection: $photoPickerItem,
                matching: .images,
                photoLibrary: .shared()
            ) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [6]))
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                        )
                        .frame(height: 180)

                    if let image = displayedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 180)
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
            }
            .buttonStyle(.plain)
            .onChange(of: photoPickerItem) { _, newItem in
                Task { await handlePhotoSelection(newItem) }
            }

            Text(summary)
                .font(.callout)

            // Extension hook: card footer
            ForEach(
                extensions.renderItems(for: trip, hook: .tripCardFooter),
                id: \.id
            ) { item in
                item.view
            }

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
                .fill(.background)
                .shadow(radius: 6)
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
    }

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
    }

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
    }

    /// Handle a new photo selection: store only the Photos local identifier and show the image
    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        if let identifier = item.itemIdentifier {
            onPhotoUpdate(trip, identifier)
            await loadExistingPhoto()
            return
        }

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
    }
}

/// Empty-state card shown when there are no upcoming trips
struct EmptyTripCard: View {
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

