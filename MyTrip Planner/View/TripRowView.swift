// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// One row displaying city/date and fetched weather summary
struct TripRowView: View {
    let trip: Trip
    @EnvironmentObject var app: AppState
    @State private var summary: String = "Fetching…"

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(trip.city).font(.headline)
                if let la = trip.latitude, let lo = trip.longitude {
                    Text(String(format: "·  %.4f, %.4f", la, lo))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(DF.med.string(from: trip.date))
                .font(.subheadline).foregroundStyle(.secondary)
            Text(summary)
                .font(.callout)
        }
        .task { await fetch() }
        .onChange(of: app.isFahrenheit) { _, _ in Task { await fetch() } }
        .swipeActions {
            Button {
                Task { await fetch() }
            } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            .tint(.blue)
        }
    } // body

    /// Fetch weather and update summary text
    private func fetch() async {
        do {
            let (hi, lo, rain) = try await WeatherService.fetchDay(for: trip)
            let hiS = Units.tempStringC(hi, isF: app.isFahrenheit)
            let loS = Units.tempStringC(lo, isF: app.isFahrenheit)
            summary = "Hi \(hiS)  ·  Lo \(loS)  ·  Rain \(rain.map { "\($0)%" } ?? "—")"
        } catch {
            dlog("UI", "TripRow fetch ERR \(error)")
            summary = "No Weather @ Loc"
        }
    } // fetch
} // TripRowView

