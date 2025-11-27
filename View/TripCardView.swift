// Copyright H2so4 Consulting LLC 2025
// File: View/TripCardView.swift

import SwiftUI
import PhotosUI

/// Trip card with editable **Place**, photos (carousel), "Suggest Picture" (ChatGPT 4o-mini)
/// and weather footer. Supports **inline Save/Cancel** when in edit mode.
/// Weather auto-updates on date/location/name changes; 1h cache prevents refetch spam.
/// end struct TripCardView
struct TripCardView: View {

    // MARK: - Inputs

    @EnvironmentObject private var app: AppState
    @Environment(\.tripEditControls) private var edit
    @Binding var trip: Trip

    // MARK: - State

    @State private var isGenerating = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectionIndex: Int = 0
    @State private var daily: DailyWeather? = nil
    @State private var loadingWeather = false
    @State private var showMapPicker = false

    // MARK: - Derived

    private var isEditing: Bool { edit.isEditing(trip.id) } // end var isEditing

    /// Weather recompute key
    /// end var weatherTaskID
    private var weatherTaskID: String {
        let unitKey = app.unit.rawValue
        let dateKey = Calendar.current.startOfDay(for: trip.date).timeIntervalSince1970
        let locKey = "\(trip.latitude ?? .nan)|\(trip.longitude ?? .nan)"
        let nameKey = (trip.customName ?? trip.locationName)
        return "\(unitKey)|\(dateKey)|\(locKey)|\(nameKey)"
    } // end var weatherTaskID

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            imageSection
            if isEditing { editButtons } // show Save/Cancel at bottom while editing
            weatherFooter
        } // end VStack
        .padding()
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemBackground)))
        .task(id: weatherTaskID) { await loadWeather() }
        .onChange(of: pickerItems) { Task { await importPickedPhotos() } }
        .sheet(isPresented: $showMapPicker) {
            MapPickerSheet(initial: app.lastPickedCoordinate ?? trip.coordinate) { pickedCoord, placeName in
                app.lastPickedCoordinate = pickedCoord
                trip.latitude = pickedCoord.latitude
                trip.longitude = pickedCoord.longitude
                if trip.isNameUserEdited == false { trip.customName = (placeName == "Unknown location") ? nil : placeName }
                Task { await loadWeather() }
            }
        } // end .sheet
    } // end var body

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {

            // "Place" on its own line
            VStack(alignment: .leading, spacing: 4) {
                Text("Place").font(.caption).foregroundStyle(.secondary)
                TextField("Place", text: Binding(
                    get: { trip.customName ?? trip.displayName },
                    set: { newValue in
                        trip.customName = newValue
                        trip.isNameUserEdited = true
                    })
                )
                .textFieldStyle(.roundedBorder)
                .font(.title2.weight(.semibold))
            } // end VStack(Place)

            HStack(spacing: 12) {
                DatePicker("", selection: Binding(get: { trip.date }, set: { trip.date = $0 }), displayedComponents: .date)
                    .labelsHidden()

                Spacer()

                Button { showMapPicker = true } label: { Label("Pick Location", systemImage: "mappin.circle") }
                    .buttonStyle(.bordered)
            } // end HStack
        } // end VStack
    } // end var header

    @ViewBuilder
    private var imageSection: some View {
        if trip.images.isEmpty {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.12)).frame(height: 220)
                VStack(spacing: 12) {
                    Text("No photos yet").font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        PhotosPicker("Add Photos", selection: $pickerItems, maxSelectionCount: 6, matching: .images)
                            .buttonStyle(.borderedProminent)
                        Button {
                            Task { await suggestPicture() }
                        } label: {
                            HStack(spacing: 8) {
                                if isGenerating { ProgressView().controlSize(.small) } // spinner while slow API
                                Image(systemName: "wand.and.stars")
                                Text(isGenerating ? "Fetching…" : "Suggest Picture")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isGenerating)
                    } // end HStack
                } // end VStack
            } // end ZStack
        } else {
            ZStack {
                TabView(selection: $selectionIndex) {
                    ForEach(Array(trip.images.enumerated()), id: \.element.id) { index, img in
                        ZStack(alignment: .topTrailing) {
                            tripImageView(img)
                                .frame(height: 240)
                                .clipped()
                                .cornerRadius(12)

                            Button(role: .destructive) { deleteImage(at: index) } label: {
                                Image(systemName: "trash")
                                    .padding(8)
                                    .background(.thinMaterial)
                                    .clipShape(Circle())
                            }
                            .padding(10)
                        } // end ZStack
                        .tag(index)
                    }
                } // end TabView
                .frame(height: 250)
                .tabViewStyle(.page(indexDisplayMode: .always))

                HStack {
                    Image(systemName: "chevron.left"); Spacer(); Image(systemName: "chevron.right")
                }
                .font(.title3).opacity(0.6).padding(.horizontal, 8).allowsHitTesting(false)
            } // end ZStack

            HStack {
                PhotosPicker("Add Photos", selection: $pickerItems, maxSelectionCount: 6, matching: .images)
                    .buttonStyle(.borderedProminent)
                Spacer(minLength: 0)
                Button { Task { await suggestPicture() } } label: {
                    HStack(spacing: 8) {
                        if isGenerating { ProgressView().controlSize(.small) }
                        Label("Suggest Picture", systemImage: "wand.and.stars")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)
            } // end HStack
        } // end if-else
    } // end var imageSection

    /// Inline edit buttons (bottom of card) shown only in edit mode.
    /// end var editButtons
    private var editButtons: some View {
        HStack {
            Button(role: .cancel) {
                edit.removeTrip(trip.id)               // discard draft
            } label: { Text("Cancel") }
            .buttonStyle(.bordered)

            Spacer()

            Button {
                edit.setEditing(trip.id, false)        // commit: just exit edit mode; data already bound
                edit.commitTrip(trip.id)
            } label: { Text("Save") }
            .buttonStyle(.borderedProminent)
            .disabled((trip.customName ?? trip.locationName).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } // end HStack
        .padding(.top, 4)
    } // end var editButtons

    private var weatherFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            if loadingWeather {
                HStack { ProgressView(); Text("Fetching forecast…") }
                    .font(.footnote).foregroundStyle(.secondary)
            } else if let d = daily {
                let unitSymbol = (app.unit == .f) ? "°F" : "°C"
                HStack(spacing: 16) {
                    Label("High: \(Int(round(d.high)))\(unitSymbol)", systemImage: "thermometer.sun")
                    Label("Low: \(Int(round(d.low)))\(unitSymbol)", systemImage: "thermometer.snowflake")
                    Label("Precip: \(Int(round(d.pop * 100)))%", systemImage: "cloud.rain")
                }
                .font(.footnote)
            } else {
                Text("No Weather Found").font(.footnote).foregroundStyle(.secondary)
            }
        } // end VStack
    } // end var weatherFooter

    // MARK: - Helpers & Actions

    @ViewBuilder
    private func tripImageView(_ img: TripImage) -> some View {
        if let file = img.fileURL, let ui = ImageStore.shared.loadImage(file) {
            Image(uiImage: ui).resizable().scaledToFill()
        } else if let url = img.remoteURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .failure(_): placeholderImage
                case .empty: ProgressView()
                @unknown default: placeholderImage
                }
            }
        } else { placeholderImage }
    } // end func tripImageView

    private var placeholderImage: some View {
        Rectangle().fill(Color.gray.opacity(0.1))
            .overlay(Text("Image unavailable").foregroundStyle(.secondary))
    } // end var placeholderImage

    private func importPickedPhotos() async {
        guard !pickerItems.isEmpty else { return }
        do {
            var newImages: [TripImage] = []
            for item in pickerItems {
                if let data = try await item.loadTransferable(type: Data.self) {
                    let saved = try ImageStore.shared.saveImage(data, source: .user)
                    let ti = TripImage(id: saved.id, fileURL: saved.fileURL, remoteURL: nil, createdAt: saved.createdAt, source: .user)
                    newImages.append(ti)
                }
            } // end for
            trip.images.append(contentsOf: newImages)
            pickerItems.removeAll()
        } catch { print("Photo import failed: \(error)") }
    } // end func importPickedPhotos

    private func suggestPicture() async {
        guard !isGenerating else { return }
        isGenerating = true
        defer { isGenerating = false }
        do {
            let service = OpenAIPhotoLinkService()
            let promptName = trip.customName?.isEmpty == false ? (trip.customName ?? "") : trip.displayName
            let img = try await service.suggestPhoto(for: promptName)
            trip.images.append(img)
        } catch {
            print("OpenAI photo link failed: \(error)")
        }
    } // end func suggestPicture

    private func deleteImage(at index: Int) {
        guard trip.images.indices.contains(index) else { return }
        let img = trip.images[index]
        if let file = img.fileURL { try? FileManager.default.removeItem(at: file) }
        trip.images.remove(at: index)
        selectionIndex = max(0, min(selectionIndex, trip.images.count - 1))
    } // end func deleteImage

    private func loadWeather() async {
        loadingWeather = true; defer { loadingWeather = false }
        do {
            let unit: TemperatureUnit = (app.unit == .f) ? .f : .c
            let svc = WeatherService()
            self.daily = try await svc.forecastForTripDate(for: trip, unit: unit)
        } catch { self.daily = nil }
    } // end func loadWeather
} // end struct TripCardView

