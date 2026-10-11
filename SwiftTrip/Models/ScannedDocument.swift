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
    var pdfData: Data? = nil        // original PDF when imported from a PDF file
    var ocrData: ExtractedDocumentData
    var category: DocumentCategory
    var predictedCategory: DocumentCategory = .other   // classifier output, before user edits
    var categoryConfidence: Double = 0                  // 0…1, see DocumentClassifier
    var isProcessing: Bool = true   // true while OCR / AI refinement is running
    var ticketLabel: String = ""
    var ocrRunID = UUID()           // ignores late results after a retake
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
        addInputs(images.map { ScanInput(image: $0) })
    }

    func addInputs(_ inputs: [ScanInput]) {
        guard !inputs.isEmpty else { return }
        let offset = scannedDocs.count
        for (i, input) in inputs.enumerated() {
            var doc = ScannedDocument(
                image: input.image,
                pdfData: input.pdfData,
                ocrData: ExtractedDocumentData(),
                category: .other,
                isProcessing: true
            )
            doc.ticketLabel = "Ticket \(offset + i + 1) of \(offset + inputs.count)"
            scannedDocs.append(doc)

            let idx = scannedDocs.count - 1
            runOCR(on: input, for: idx)
        }
        currentIndex = offset   // show first newly added
    }

    func replaceImage(_ image: UIImage, at index: Int) {
        replaceInput(ScanInput(image: image), at: index)
    }

    func replaceInput(_ input: ScanInput, at index: Int) {
        guard scannedDocs.indices.contains(index) else { return }
        scannedDocs[index].image = input.image
        scannedDocs[index].pdfData = input.pdfData
        scannedDocs[index].isProcessing = true
        runOCR(on: input, for: index)
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

    private func runOCR(on input: ScanInput, for index: Int) {
        guard scannedDocs.indices.contains(index) else { return }
        let runID = UUID()
        scannedDocs[index].ocrRunID = runID
        // A retake starts fresh: the new result may replace the old category.
        scannedDocs[index].predictedCategory = scannedDocs[index].category

        let handle: (ExtractedDocumentData) -> Void = { [weak self] data in
            guard let self else { return }
            // 1. Rules first — instant result.
            let rules = DocumentClassifier.shared.classifyWithConfidence(data: data)
            let assistant = DocumentAIAssistant.shared
            let needsAssist = assistant.shouldAssist(data, rules: rules)
            self.apply(data, rules, runID: runID, finished: !needsAssist)
            guard needsAssist else { return }

            // 2. On-device Foundation Model refines unsure results / fills gaps.
            Task { [weak self] in
                let (refined, result) = await assistant.refine(data, rules: rules)
                self?.apply(refined, result, runID: runID, finished: true)
            }
        }

        if let text = input.pdfText {
            // Digital PDF: its text layer is exact — skip OCR.
            handle(VisionOCRService.shared.extract(fromText: text))
        } else if !input.pagesForOCR.isEmpty {
            // Scanned PDF: OCR every rendered page as one document.
            VisionOCRService.shared.recognise(pages: input.pagesForOCR, completion: handle)
        } else {
            VisionOCRService.shared.recognise(image: input.image, completion: handle)
        }
    }

    private func apply(_ data: ExtractedDocumentData,
                       _ result: DocumentClassification,
                       runID: UUID,
                       finished: Bool) {
        // Look up by run ID: indices shift when docs are removed, and a retake
        // starts a new run whose results must not be overwritten by this one.
        guard let index = scannedDocs.firstIndex(where: { $0.ocrRunID == runID }) else { return }
        var data = data
        data.isBoardingPass = result.category == .boardingPass
        // Keep a category the user already picked while the AI was still running.
        let userEdited = scannedDocs[index].category != scannedDocs[index].predictedCategory
        scannedDocs[index].ocrData            = data
        if !userEdited { scannedDocs[index].category = result.category }
        scannedDocs[index].predictedCategory  = result.category
        scannedDocs[index].categoryConfidence = result.confidence
        scannedDocs[index].isProcessing       = !finished
    }
}
