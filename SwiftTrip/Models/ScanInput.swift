//
//  ScanInput.swift
//  hh
//
//  One item entering the scan flow: a photo, an image file or a PDF.
//  A PDF becomes one document — its first page is the preview image, and
//  its text comes from the PDF's own text layer when it has one (e-tickets,
//  booking confirmations) or from OCR of the rendered pages (scanned PDFs).
//

import UIKit
import PDFKit

struct ScanInput {
    /// Preview / stored image (first page for PDFs).
    var image: UIImage
    /// Original PDF bytes, kept so the saved document can show every page.
    var pdfData: Data? = nil
    /// Text extracted from the PDF's text layer, if it has a usable one.
    var pdfText: String? = nil
    /// Rendered pages to OCR when the PDF has no text layer (scanned PDFs).
    var pagesForOCR: [UIImage] = []

    var isPDF: Bool { pdfData != nil }

    /// Max pages rendered for OCR — keeps memory and time bounded for long PDFs.
    static let maxOCRPages = 5
    /// A text layer shorter than this is treated as "no text" (scanned PDF).
    static let minimumPDFTextLength = 30

    init(image: UIImage) {
        self.image = image
    }

    /// Loads an image or PDF from a file URL (Files app, share sheet …).
    /// Caller handles security-scoped access.
    static func load(from url: URL) -> ScanInput? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        if url.pathExtension.lowercased() == "pdf" || data.starts(with: Array("%PDF".utf8)) {
            return fromPDF(data: data)
        }
        guard let image = UIImage(data: data) else { return nil }
        return ScanInput(image: image.downsampledForOCR())
    }

    static func fromPDF(data: Data) -> ScanInput? {
        guard let document = PDFDocument(data: data),
              document.pageCount > 0,
              let firstPage = document.page(at: 0),
              let preview = UIImage.renderPDFPage(firstPage, scale: 2)
        else { return nil }

        var input = ScanInput(image: preview.downsampledForOCR())
        input.pdfData = data

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0)?.string }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if text.count >= minimumPDFTextLength {
            input.pdfText = text
        } else {
            // Scanned PDF — render pages for OCR (first page already rendered).
            input.pagesForOCR = [input.image] + (1..<min(document.pageCount, maxOCRPages)).compactMap {
                document.page(at: $0)
                    .flatMap { UIImage.renderPDFPage($0, scale: 2) }?
                    .downsampledForOCR()
            }
        }
        return input
    }
}
