//
//  SharedDocumentStore.swift
//  hh  (add to BOTH the app target AND the widget extension target)
//

import Foundation
import UIKit

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

        let sharedImagePath = copyImageToSharedContainer(from: doc.imageName)

        let snapshot = WidgetDocumentSnapshot(
            id:             doc.id.uuidString,
            categoryId:     categoryId,
            tripId:         tripId,
            name:           doc.name,
            categoryName:   doc.categoryName,
            notePreview:    firstMeaningfulLine(doc.note),
            imagePath:      sharedImagePath ?? doc.imageName,
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

    private func copyImageToSharedContainer(from sourcePath: String) -> String? {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else { return nil }

        if sourcePath.contains(containerURL.path) { return sourcePath }

        let destURL = containerURL.appendingPathComponent(
            "widget_images/\(UUID().uuidString).jpg"
        )
        try? FileManager.default.createDirectory(
            at: destURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        guard let image = UIImage(contentsOfFile: sourcePath)
               ?? UIImage(contentsOfFile: documentsURL(for: sourcePath).path)
        else { return nil }

        let thumbnail = resizedForWidget(image, maxSide: 320, maxArea: 300_000)
        guard let data = thumbnail.jpegData(compressionQuality: 0.75)
        else { return nil }

        try? data.write(to: destURL)
        return destURL.path
    }

    private func resizedForWidget(_ image: UIImage, maxSide: CGFloat, maxArea: CGFloat) -> UIImage {
        let size = image.size
        let sideScale = min(maxSide / size.width, maxSide / size.height, 1)
        let area = size.width * size.height
        let areaScale = area > maxArea ? sqrt(maxArea / area) : 1
        let scale = min(sideScale, areaScale)

        guard scale < 1 else { return image }

        let newSize = CGSize(width: (size.width  * scale).rounded(),
                             height: (size.height * scale).rounded())
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    private func documentsURL(for filename: String) -> URL {
        let name = URL(fileURLWithPath: filename).lastPathComponent
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
    }
}
