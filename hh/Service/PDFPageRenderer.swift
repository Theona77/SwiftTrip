//
//  PDFPageRenderer.swift
//  hh
//
//  Created by Theona Arlinton on 27/04/26.
//

import PDFKit
import UIKit

extension UIImage {
    static func renderPDFFirstPage(from url: URL, scale: CGFloat = 2.0) -> UIImage? {
        guard let doc = PDFDocument(url: url), let page = doc.page(at: 0) else { return nil }
        return renderPDFPage(page, scale: scale)
    }

    static func renderAllPDFPages(from url: URL, scale: CGFloat = 1.5) -> [UIImage] {
        guard let doc = PDFDocument(url: url) else { return [] }
        return (0..<doc.pageCount).compactMap { renderPDFPage(doc.page(at: $0)!, scale: scale) }
    }

    private static func renderPDFPage(_ page: PDFPage, scale: CGFloat) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.white.set()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.translateBy(x: 0, y: size.height)
            ctx.cgContext.scaleBy(x: scale, y: -scale)
            page.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
