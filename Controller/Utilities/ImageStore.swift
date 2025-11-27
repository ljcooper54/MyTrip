// Copyright H2so4 Consulting LLC 2025
// File: Utilities/ImageStore.swift

import UIKit

/// Simple disk-backed image store for `TripImage`.
/// - All saves return a `TripImage` with `fileURL` set and `remoteURL == nil`.
/// - Loading accepts an optional `URL?`.
/// - Delete is safe if `fileURL` is `nil`.
/// end final class ImageStore
final class ImageStore {

    // MARK: - Singleton

    static let shared = ImageStore()
    private init() {} // end init

    // MARK: - Paths

    /// Returns/creates the app's Images directory inside Documents.
    /// end func imagesDir()
    private func imagesDir() throws -> URL {
        let base = try FileManager.default.url(for: .documentDirectory,
                                               in: .userDomainMask,
                                               appropriateFor: nil,
                                               create: true)
        let dir = base.appendingPathComponent("Images", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    } // end func imagesDir()

    // MARK: - API

    /// Saves raw image data to disk (JPEG/PNG/etc. as provided) and returns a `TripImage`.
    /// - Sets `remoteURL` to `nil` because this is a local save.
    /// end func saveImage(_:source:)
    func saveImage(_ data: Data, source: TripImageSource) throws -> TripImage {
        let filename = UUID().uuidString + ".jpg"
        let dest = try imagesDir().appendingPathComponent(filename)
        try data.write(to: dest, options: .atomic)

        return TripImage(
            id: UUID(),
            fileURL: dest,
            remoteURL: nil,
            createdAt: Date(),
            source: source
        )
    } // end func saveImage(_:source:)

    /// Loads a UIImage from an optional local file URL.
    /// - Returns `nil` if the URL is `nil` or unreadable.
    /// end func loadImage(_:)
    func loadImage(_ url: URL?) -> UIImage? {
        guard let url else { return nil }
        return UIImage(contentsOfFile: url.path)
    } // end func loadImage(_:)

    /// Deletes the local file associated with a `TripImage` if present.
    /// - Safe no-op if `fileURL` is `nil` or the file is missing.
    /// end func deleteImage(_:)
    func deleteImage(_ image: TripImage) throws {
        guard let url = image.fileURL else { return }           // nothing to delete
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)         // FIX: removeItem (not remoteItem)
        }
    } // end func deleteImage(_:)
} // end final class ImageStore

