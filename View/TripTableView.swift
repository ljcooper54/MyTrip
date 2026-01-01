// Copyright H2so4 Consulting LLC 2025
// File: View/TripTableView.swift

import SwiftUI

/// Grid presentation (iPad or landscape): Name, Date, Weather, Location (if provided).
/// Shows the most recent 200 trips by default, expanding when the user scrolls back to the start.
/// end struct TripTableView
struct TripTableView: View {

    // MARK: - Inputs

    @EnvironmentObject private var app: AppState
    @State private var weatherMap: [UUID: DailyWeather] = [:]
    @State private var weatherStatus: [UUID: WeatherStatus] = [:]
    @State private var displayCount: Int = 0
    @State private var hasSeenTopOnce = false
    var trips: [Trip] // read-only

    // MARK: - Body

    var body: some View {
        let sorted = trips.sorted { $0.date < $1.date }
        let displayed = displayedTrips(from: sorted)

        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(displayed) { trip in
                    TripSummaryCard(
                        trip: trip,
                        weather: weatherMap[trip.id],
                        status: weatherStatus[trip.id] ?? .loading,
                        unit: app.unit
                    )
                    .onAppear {
                        loadMoreIfNeeded(currentTripID: trip.id, displayed: displayed, totalCount: sorted.count)
                    }
                } // end ForEach
            } // end LazyVGrid
            .padding()
        }
        .task(id: weatherTaskID(for: displayed)) { await loadAllWeather(for: displayed) }
        .onAppear {
            if displayCount == 0 {
                displayCount = min(200, sorted.count)
            }
        }
    } // end var body

    // MARK: - Helpers

    private func loadAllWeather(for sorted: [Trip]) async {
        let svc = WeatherService()
        let unit: TemperatureUnit = (app.unit == .f) ? .f : .c
        let ids = Set(sorted.map(\.id))
        await MainActor.run {
            weatherMap = weatherMap.filter { ids.contains($0.key) }
            weatherStatus = weatherStatus.filter { ids.contains($0.key) }
        }
        let chunks = chunked(sorted, size: 12)
        var newMap: [UUID: DailyWeather] = [:]
        var newStatus: [UUID: WeatherStatus] = [:]
        for chunk in chunks {
            await withTaskGroup(of: (UUID, WeatherStatus, DailyWeather?).self) { group in
                for t in chunk {
                    group.addTask {
                        do {
                            let v = try await svc.forecastForTripDate(for: t, unit: unit)
                            if let v {
                                return (t.id, .ready, v)
                            }
                            return (t.id, .noForecast, nil)
                        } catch {
                            return (t.id, .failed, nil)
                        }
                    }
                } // end for
                for await (id, status, value) in group {
                    newStatus[id] = status
                    if let value {
                        newMap[id] = value
                    }
                }
            } // end withTaskGroup
        }
        await MainActor.run {
            weatherMap = newMap
            weatherStatus = newStatus
        }
    } // end func loadAllWeather

    private var gridColumns: [GridItem] {
        [
            GridItem(.adaptive(minimum: 220), spacing: 12, alignment: .topLeading)
        ]
    } // end var gridColumns

    private func displayedTrips(from sorted: [Trip]) -> [Trip] {
        guard !sorted.isEmpty else { return [] }
        let count = min(max(displayCount, 1), sorted.count)
        let startIndex = max(sorted.count - count, 0)
        return Array(sorted[startIndex..<sorted.count])
    } // end func displayedTrips

    private func chunked<T>(_ items: [T], size: Int) -> [[T]] {
        guard size > 0 else { return [items] }
        var chunks: [[T]] = []
        var index = 0
        while index < items.count {
            let end = min(index + size, items.count)
            chunks.append(Array(items[index..<end]))
            index = end
        }
        return chunks
    } // end func chunked

    private func loadMoreIfNeeded(currentTripID: UUID, displayed: [Trip], totalCount: Int) {
        guard let first = displayed.first, first.id == currentTripID else { return }
        guard displayed.count < totalCount else { return }
        if !hasSeenTopOnce {
            hasSeenTopOnce = true
            return
        }
        displayCount = min(displayCount + 200, totalCount)
    } // end func loadMoreIfNeeded

    private func weatherTaskID(for trips: [Trip]) -> String {
        let firstID = trips.first?.id.uuidString ?? "none"
        let lastID = trips.last?.id.uuidString ?? "none"
        return "\(firstID)_\(lastID)_\(trips.count)_\(app.unit.rawValue)"
    } // end func weatherTaskID
} // end struct TripTableView

// MARK: - Grid Card

/// end struct TripSummaryCard
private struct TripSummaryCard: View {
    let trip: Trip
    let weather: DailyWeather?
    let status: WeatherStatus
    let unit: AppState.TempUnit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.displayName)
                .font(.headline)
                .lineLimit(2)

            Text(trip.date, style: .date)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            weatherRow

            if let coordinate = trip.coordinate {
                let lat = String(format: "%.3f", coordinate.latitude)
                let lon = String(format: "%.3f", coordinate.longitude)
                Text("Location: \(lat), \(lon)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    } // end var body

    @ViewBuilder
    private var weatherRow: some View {
        if let weather {
            let unitLabel = unit == .f ? "°F" : "°C"
            Text("Weather: \(Int(round(weather.high)))\(unitLabel) / \(Int(round(weather.low)))\(unitLabel) • \(Int(round(weather.pop * 100)))%")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if status == .noForecast {
            Text("Weather: No Weather")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if status == .failed {
            Text("Weather: Unavailable")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Weather: Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    } // end var weatherRow
} // end struct TripSummaryCard

private enum WeatherStatus: Equatable {
    case loading
    case ready
    case noForecast
    case failed
} // end enum WeatherStatus
