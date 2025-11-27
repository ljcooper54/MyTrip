// ============================================================================
// Copyright H2so4 Consulting LLC 2025
// File: View/TripRowView.swift
// ============================================================================

import SwiftUI
import UIKit

/// Compact row for lists/tables; shows a small thumbnail, display name, and date.
/// Handles optional local fileURL and remoteURL without force-unwrapping.
/// end struct TripRowView
struct TripRowView: View {

    // MARK: - Inputs

    let trip: Trip

    // MARK: - Computed

    private var title: String { trip.displayName } // user-sticky naming logic

    // MARK: - Body

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(trip.date, style: .date)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } // end VStack

            Spacer()
        } // end HStack
        .padding(.vertical, 6)
        .contentShape(Rectangle()) // why: make the whole row tappable in lists
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(formattedDate)")
    } // end var body

    // MARK: - Pieces

    private var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: trip.date)
    } // end var formattedDate

    /// Renders the first image: prefers local file; falls back to remote URL; else placeholder.
    /// end var thumbnailView
    @ViewBuilder
    private var thumbnailView: some View {
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
            } else {
                placeholder
            }
        } else {
            placeholder
        }
    } // end var thumbnailView

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.secondary.opacity(0.15))
            .overlay(
                Image(systemName: "photo")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
            )
    } // end var placeholder
} // end struct TripRowView


