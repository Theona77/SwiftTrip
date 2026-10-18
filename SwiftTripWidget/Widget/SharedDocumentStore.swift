//
//  SharedDocumentStore.swift
//  hh  (add to BOTH the app target AND the widget extension target)
//

import Foundation
import UIKit
import ImageIO

// MARK: - Category shortcut (kept for API compatibility; widget no longer renders it)

struct WidgetCategoryShortcut: Codable, Identifiable {
    let id: String
    let tripId: String
    let name: String
    let icon: String
    let colorHex: String
}

// MARK: - Snapshot

struct WidgetDocumentSnapshot: Codable {
    let id: String
    let categoryId: String
    let tripId: String
    let name: String
    let categoryName: String
    let notePreview: String
    let imagePath: String
    let startDate: Date?
    let endDate: Date?
    let topCategories: [WidgetCategoryShortcut]   // reserved; widget ignores this
}

// MARK: - Store

final class SharedDocumentStore {

    static let shared = SharedDocumentStore()
    private init() {}

    private let appGroupID  = "group.com.hh.documents"
    private let snapshotKey = "widget_next_document"

    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    // MARK: - Write (called from main app)

    func updateWidgetSnapshot(trips: [TripModel],
                              globalCategories: [CategoryModel],
                              recentDocuments: [DocumentModel] = []) {
        guard let defaults = sharedDefaults else { return }

        guard let (doc, categoryId, tripId) = pickNextDocument(
            trips: trips,
            globals: globalCategories,
            recents: recentDocuments
        ) else {
            defaults.removeObject(forKey: snapshotKey)
            return
        }

        let sharedImagePath = copyImageToSharedContainer(from: doc.imageName, documentID: doc.id)

        let snapshot = WidgetDocumentSnapshot(
            id:             doc.id.uuidString,
            categoryId:     categoryId,
            tripId:         tripId,
            name:           doc.name,
            categoryName:   doc.categoryName,
            notePreview:    firstMeaningfulLine(doc.note),
            imagePath:      sharedImagePath ?? "",
            startDate:      doc.startDate,
            endDate:        doc.endDate,
            topCategories:  []          // shortcuts no longer used by widget
        )

        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
        }
    }

    // MARK: - Read (widget)

    func loadSnapshot() -> WidgetDocumentSnapshot? {
        guard
            let defaults = sharedDefaults,
            let data     = defaults.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(WidgetDocumentSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    // MARK: - Pick document
    // Returns (document, categoryId, tripId).
    // Priority: soon (≤2 days), active now, most recently viewed, upcoming, last ended.

    private func pickNextDocument(
        trips: [TripModel],
        globals: [CategoryModel],
        recents: [DocumentModel]
    ) -> (DocumentModel, String, String)? {

        var pool: [(doc: DocumentModel, catId: String, tripId: String)] = []

        for trip in trips {
            for cat in trip.categories {
                for doc in cat.documents {
                    pool.append((doc, cat.id.uuidString, trip.id.uuidString))
                }
            }
        }
        for cat in globals {
            for doc in cat.documents {
                pool.append((doc, cat.id.uuidString, ""))
            }
        }

        guard !pool.isEmpty else { return nil }

        let now        = Date()
        let soonWindow = Calendar.current.date(byAdding: .day, value: 2, to: now) ?? now

        // 1. Starting very soon (next 2 days)
        if let hit = pool
            .filter({ ($0.doc.startDate ?? .distantFuture) >= now
                   && ($0.doc.startDate ?? .distantFuture) <= soonWindow })
            .sorted(by: { ($0.doc.startDate ?? .distantFuture) < ($1.doc.startDate ?? .distantFuture) })
            .first {
            return (hit.doc, hit.catId, hit.tripId)
        }

        // 2. Currently active (startDate ≤ now ≤ endDate)
        if let hit = pool
            .filter({ ($0.doc.startDate ?? .distantPast) <= now
                   && ($0.doc.endDate   ?? .distantPast) >= now })
            .sorted(by: { ($0.doc.endDate ?? .distantFuture) < ($1.doc.endDate ?? .distantFuture) })
            .first {
            return (hit.doc, hit.catId, hit.tripId)
        }

        // 3. Most recently viewed
        for recent in recents {
            if let hit = pool.first(where: { $0.doc.id == recent.id }) {
                return (hit.doc, hit.catId, hit.tripId)
            }
        }

        // 4. Next upcoming
        if let hit = pool
            .filter({ ($0.doc.startDate ?? .distantPast) > now })
            .sorted(by: { ($0.doc.startDate ?? .distantFuture) < ($1.doc.startDate ?? .distantFuture) })
            .first {
            return (hit.doc, hit.catId, hit.tripId)
        }

        // 5. Most recently ended
        if let hit = pool
            .filter({ $0.doc.endDate != nil })
            .sorted(by: { ($0.doc.endDate ?? .distantPast) > ($1.doc.endDate ?? .distantPast) })
            .first {
            return (hit.doc, hit.catId, hit.tripId)
        }

        // 6. Anything
        return pool.last.map { ($0.doc, $0.catId, $0.tripId) }
    }

    // MARK: - Helpers

    private func firstMeaningfulLine(_ note: String) -> String {
        note.split(separator: "\n").first.map(String.init) ?? ""
    }

    private static let widgetImageFolder = "widget_images"

    /// Resolves a snapshot's `imagePath` to a file in the App Group container.
    /// Current snapshots store a path relative to the container; older ones
    /// stored an absolute path, which is still honoured if the file exists.
    func imageURL(for imagePath: String) -> URL? {
        guard !imagePath.isEmpty else { return nil }
        if imagePath.hasPrefix("/") {
            return FileManager.default.fileExists(atPath: imagePath)
                ? URL(fileURLWithPath: imagePath) : nil
        }
        return FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent(imagePath)
    }

    /// Writes one thumbnail per snapshot to the shared container and deletes
    /// every older thumbnail, so the folder never grows. Returns the path
    /// relative to the container (absolute container paths can change).
    private func copyImageToSharedContainer(from sourcePath: String, documentID: UUID) -> String? {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return nil }

        let folderURL = containerURL.appendingPathComponent(Self.widgetImageFolder, isDirectory: true)
        // A new name per write makes WidgetKit pick up a replaced photo.
        let fileName = "\(documentID.uuidString)-\(UUID().uuidString.prefix(8)).jpg"
        let destURL = folderURL.appendingPathComponent(fileName)

        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        // Decode straight to thumbnail size; a full decode of a camera photo is slow and ~48 MB.
        guard let thumbnail = downsampledImage(at: URL(fileURLWithPath: sourcePath), maxSide: 320)
               ?? downsampledImage(at: documentsURL(for: sourcePath), maxSide: 320)
        else {
            removeWidgetImages(in: folderURL, except: nil)
            return nil
        }

        guard let data = thumbnail.jpegData(compressionQuality: 0.75),
              (try? data.write(to: destURL, options: .atomic)) != nil
        else { return nil }

        removeWidgetImages(in: folderURL, except: fileName)
        return "\(Self.widgetImageFolder)/\(fileName)"
    }

    private func removeWidgetImages(in folderURL: URL, except keep: String?) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folderURL.path)) ?? []
        for file in files where file != keep {
            try? FileManager.default.removeItem(at: folderURL.appendingPathComponent(file))
        }
    }

    private func downsampledImage(at url: URL, maxSide: CGFloat) -> UIImage? {
        guard !url.path.isEmpty,
              FileManager.default.fileExists(atPath: url.path),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxSide
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func documentsURL(for filename: String) -> URL {
        let name = URL(fileURLWithPath: filename).lastPathComponent
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }
}
