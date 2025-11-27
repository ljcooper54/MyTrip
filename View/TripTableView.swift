// Copyright H2so4 Consulting LLC 2025
// File: View/TripTableView.swift

import SwiftUI

/// Table/grid presentation (iPad or landscape): **Photo**, Date, Place, High, Low, Precip.
/// Now includes a thumbnail column (first trip image, local or remote).
/// end struct TripTableView
struct TripTableView: View {

    // MARK: - Inputs

    @EnvironmentObject private var app: AppState
    @State private var weatherMap: [UUID: DailyWeather] = [:]
    var trips: [Trip] // read-only

    // MARK: - Body

    var body: some View {
        let sorted = trips.sorted { $0.date < $1.date }
        Table(sorted) {
            TableColumn("Photo") { trip in
                TableThumbnail(trip: trip)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } // end TableColumn(Photo)

            TableColumn("Date") { trip in
                Text(trip.date, style: .date)
            } // end TableColumn(Date)

            TableColumn("Place") { trip in
                Text(trip.displayName).lineLimit(1)
            } // end TableColumn(Place)

            TableColumn("High") { trip in
                let unit = app.unit == .f ? "°F" : "°C"
                Text(value(for: trip).map { "\(Int(round($0.high)))\(unit)" } ?? "—")
            } // end TableColumn(High)

            TableColumn("Low") { trip in
                let unit = app.unit == .f ? "°F" : "°C"
                Text(value(for: trip).map { "\(Int(round($0.low)))\(unit)" } ?? "—")
            } // end TableColumn(Low)

            TableColumn("Precip") { trip in
                Text(value(for: trip).map { "\(Int(round($0.pop * 100)))%" } ?? "—")
            } // end TableColumn(Precip)
        } // end Table
        .task(id: app.unit.rawValue) { await loadAllWeather(for: sorted) }
    } // end var body

    // MARK: - Helpers

    private func value(for trip: Trip) -> DailyWeather? { weatherMap[trip.id] } // end func value(for:)

    private func loadAllWeather(for sorted: [Trip]) async {
        let svc = WeatherService()
        let unit: TemperatureUnit = (app.unit == .f) ? .f : .c
        await withTaskGroup(of: (UUID, DailyWeather?).self) { group in
            for t in sorted {
                group.addTask {
                    let v = try? await svc.forecastForTripDate(for: t, unit: unit)
                    return (t.id, v)
                }
            } // end for
            var newMap: [UUID: DailyWeather] = [:]
            for await (id, v) in group { if let v { newMap[id] = v } }
            weatherMap = newMap
        } // end withTaskGroup
    } // end func loadAllWeather
} // end struct TripTableView

// MARK: - Table Thumbnail Cell

/// Renders a 48x48 thumbnail from the first image (local preferred; remote via AsyncImage).
/// end struct TableThumbnail
struct TableThumbnail: View {
    let trip: Trip

    var body: some View {
        if let first = trip.images.first {
            if let file = first.fileURL, let ui = ImageStore.shared.loadImage(file) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let url = first.remoteURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure(_): placeholder
                    case .empty: ProgressView()
                    @unknown default: placeholder
                    }
                }
            } else { placeholder }
        } else { placeholder }
    } // end var body

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.15))
            .overlay(Image(systemName: "photo").imageScale(.small).foregroundStyle(.secondary))
    } // end var placeholder
} // end struct TableThumbnail

