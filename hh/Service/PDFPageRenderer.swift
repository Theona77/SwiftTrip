//
//  PDFPageRenderer.swift
//  hh
//
//  Created by Theona Arlinton on 27/04/26.
//
//  nonisolated: PDFKit rendering is thread-safe, so the viewer renders
//  pages off the main thread.
//

import PDFKit
import UIKit

extension UIImage {
    nonisolated static func renderPDFFirstPage(from url: URL, scale: CGFloat = 2.0) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        return renderPDFPage(page, scale: scale)
    }

    nonisolated static func renderAllPDFPages(from url: URL, scale: CGFloat = 1.5) -> [UIImage] {
        guard let doc = PDFDocument(url: url) else { return [] }
        return renderPages(of: doc, scale: scale)
    }

    nonisolated static func renderAllPDFPages(from data: Data, scale: CGFloat = 1.5) -> [UIImage] {
        guard let doc = PDFDocument(data: data) else { return [] }
        return renderPages(of: doc, scale: scale)
    }

    /// Caps the page count so a huge PDF can't exhaust memory in the viewer.
    nonisolated private static func renderPages(of doc: PDFDocument, scale: CGFloat, maxPages: Int = 30) -> [UIImage] {
        (0..<min(doc.pageCount, maxPages)).compactMap { index in
            doc.page(at: index).flatMap { renderPDFPage($0, scale: scale) }
        }
    }

    nonisolated static func renderPDFPage(_ page: PDFPage, scale: CGFloat) -> UIImage? {
        // Respect the page's /Rotate flag — landscape e-tickets are often stored rotated.
        var pageSize = page.bounds(for: .mediaBox).size
        if abs(page.rotation) % 180 == 90 {
            pageSize = CGSize(width: pageSize.height, height: pageSize.width)
        }
        let size = CGSize(width: pageSize.width * scale, height: pageSize.height * scale)
        guard size.width > 0, size.height > 0 else { return nil }

        let rendered = page.thumbnail(of: size, for: .mediaBox)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            rendered.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
