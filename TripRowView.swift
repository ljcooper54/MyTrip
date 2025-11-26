// Copyright 2025 H2so4 Consulting LLC
import SwiftUI

/// One row displaying city/date and fetched weather summary for table mode
struct TripRowView: View {
    let trip: Trip
    @EnvironmentObject var app: AppState
    @EnvironmentObject var extensions: TripExtensionRegistry
    @State private var summary: String = "Fetching…"

    /// True if the trip is today or in the future
    private var isTodayOrFuture: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: trip.date) >= today
    }

    /// Main body of the table row
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(trip.city.isEmpty ? "Unknown City" : trip.city)
                    .font(.headline)

                if let la = trip.latitude, let lo = trip.longitude {
                    Text(String(format: "·  %.4f, %.4f", la, lo))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(DF.med.string(from: trip.date))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(summary)
                .font(.footnote)

            // Extension hook: row footer
            ForEach(
                extensions.renderItems(for: trip, hook: .tripRowFooter),
                id: \.id
            ) { item in
                item.view
            }
        }
        .task {
            guard isTodayOrFuture else {
                summary = "Trip date has passed"
                return
            }
            await fetch()
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
            dlog("UI", "TripRow fetch ERR \(error)")
            summary = "No Weather @ Loc"
        }
    } // fetch
} // TripRowView

