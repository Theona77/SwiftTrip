//
//  ScannedDocument.swift
//  hh
//
//  Created by Theona Arlinton on 19/04/26.
//

import SwiftUI
import Combine

// MARK: - ScannedDocument

struct ScannedDocument: Identifiable {
    let id = UUID()
    var image: UIImage
    var ocrData: ExtractedDocumentData
    var category: DocumentCategory
    var isProcessing: Bool = true   // true while OCR is running
    var ticketLabel: String = ""
}

// MARK: - ScanStore  (ObservableObject passed through the scan flow)

final class ScanStore: ObservableObject {
    @Published var scannedDocs: [ScannedDocument] = []
    @Published var currentIndex: Int = 0      // which doc is on screen

    var currentDoc: ScannedDocument? {
        guard scannedDocs.indices.contains(currentIndex) else { return nil }
        return scannedDocs[currentIndex]
    }

    var totalCount: Int { scannedDocs.count }

    // ── Intake ────────────────────────────────────────────────────────────
    func addImages(_ images: [UIImage]) {
        let offset = scannedDocs.count
        for (i, img) in images.enumerated() {
            var doc = ScannedDocument(
                image: img,
                ocrData: ExtractedDocumentData(),
                category: .other,
                isProcessing: true
            )
            doc.ticketLabel = "Ticket \(offset + i + 1) of \(offset + images.count)"
            scannedDocs.append(doc)

            let idx = scannedDocs.count - 1
            runOCR(on: img, for: idx)
        }
        currentIndex = offset   // show first newly added
    }

    func replaceImage(_ image: UIImage, at index: Int) {
        guard scannedDocs.indices.contains(index) else { return }
        scannedDocs[index].image = image
        scannedDocs[index].isProcessing = true
        runOCR(on: image, for: index)
    }

    func setCategory(_ cat: DocumentCategory, at index: Int) {
        guard scannedDocs.indices.contains(index) else { return }
        scannedDocs[index].category = cat
    }

    func remove(at index: Int) {
        guard scannedDocs.indices.contains(index) else { return }
        scannedDocs.remove(at: index)
        relabelTickets()
        currentIndex = max(0, min(currentIndex, scannedDocs.count - 1))
    }

    func removeAll() { scannedDocs.removeAll(); currentIndex = 0 }

    func removeDocument(id: UUID) {
        guard let index = scannedDocs.firstIndex(where: { $0.id == id }) else { return }
        scannedDocs.remove(at: index)
        relabelTickets()
        currentIndex = min(index, max(0, scannedDocs.count - 1))
    }

    // ── Private ───────────────────────────────────────────────────────────

    private func relabelTickets() {
        for i in scannedDocs.indices {
            scannedDocs[i].ticketLabel = "Ticket \(i + 1) of \(scannedDocs.count)"
        }
    }

    private func runOCR(on image: UIImage, for index: Int) {
        VisionOCRService.shared.recognise(image: image) { [weak self] data in
            guard let self = self,
                  self.scannedDocs.indices.contains(index) else { return }
            let category = DocumentClassifier.shared.classify(data: data)
            self.scannedDocs[index].ocrData    = data
            self.scannedDocs[index].category   = category
            self.scannedDocs[index].isProcessing = false
        }
    }
}
