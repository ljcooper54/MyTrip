//
//  TripExtensionHook.swift
//  MyTrip Planner
//
//  Created by Lorne Cooper on 11/26/25.
//


// =================================
// File: TripExtensions.swift (NEW)
// =================================

import SwiftUI
import Combine

/// Where an extension can render UI.
enum TripExtensionHook {
    case tripCardFooter     // Below the weather summary on cards
    case tripRowFooter      // Below the summary in table rows
}

/// Metadata describing an extension.
struct TripExtensionMetadata {
    let id: String          // Stable, e.g. "com.mytrip.extensions.countdown"
    let displayName: String
    let author: String
    let version: String
    let supportedHooks: [TripExtensionHook]
}

/// Render-ready item for a given hook.
struct TripExtensionRenderItem {
    let id: String
    let view: AnyView
}

/// Contract for any extension.
protocol TripExtensionProviding {
    var metadata: TripExtensionMetadata { get }

    func supports(hook: TripExtensionHook) -> Bool
    func makeView(for trip: Trip, hook: TripExtensionHook) -> AnyView?
}

extension TripExtensionProviding {
    func supports(hook: TripExtensionHook) -> Bool {
        metadata.supportedHooks.contains(hook)
    }
}

/// Registry that holds all installed extensions.
final class TripExtensionRegistry: ObservableObject {
    @Published private(set) var allExtensions: [any TripExtensionProviding]

    init(extensions: [any TripExtensionProviding]) {
        self.allExtensions = extensions
    }

    convenience init() {
        self.init(extensions: TripExtensionRegistry.defaultExtensions())
    }

    func renderItems(for trip: Trip, hook: TripExtensionHook) -> [TripExtensionRenderItem] {
        allExtensions.compactMap { ext in
            guard ext.supports(hook: hook),
                  let view = ext.makeView(for: trip, hook: hook) else {
                return nil
            }
            return TripExtensionRenderItem(id: ext.metadata.id, view: view)
        }
    }

    private static func defaultExtensions() -> [any TripExtensionProviding] {
        [
            CountdownExtension()
        ]
    }
}

/// Example extension: shows days until (or since) the trip.
struct CountdownExtension: TripExtensionProviding {
    let metadata = TripExtensionMetadata(
        id: "com.mytrip.extensions.countdown",
        displayName: "Trip Countdown",
        author: "MyTrip",
        version: "1.0.0",
        supportedHooks: [.tripCardFooter, .tripRowFooter]
    )

    func makeView(for trip: Trip, hook: TripExtensionHook) -> AnyView? {
        let label = countdownLabel(for: trip.date)
        let view = Text(label)
            .font(.footnote)
            .foregroundStyle(.secondary)
        return AnyView(view)
    }

    private func countdownLabel(for date: Date) -> String {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let tripDay = cal.startOfDay(for: date)
        let comps = cal.dateComponents([.day], from: today, to: tripDay)
        let days = comps.day ?? 0

        if days > 0 {
            return days == 1 ? "1 day from today" : "\(days) days from today"
        } else if days == 0 {
            return "Today"
        } else {
            let pastDays = -days
            return pastDays == 1 ? "1 day ago" : "\(pastDays) days ago"
        }
    }
}
