//
//  UIImage+LocalStorage.swift
//  hh
//
//  Created by Theona Arlinton on 24/04/26.
//

// Ambil gambar dari disk, coba pakai path langsung dulu, kalau gagal coba cari di Documents folder berdasarkan nama file.
// Gambar disimpan di app sandbox, tepatnya di Documents directory.

import UIKit
import ImageIO

extension UIImage {
    /// Full-resolution decode. Expensive (a camera photo is ~48 MB once decoded),
    /// so only use it where full detail is needed, e.g. the zoomable viewer.
    static func loadFromDocuments(named filename: String) -> UIImage? {
        guard let url = documentFileURL(named: filename) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    /// Cheap existence check — no decoding. Use instead of `loadFromDocuments(...) != nil`.
    static func documentImageExists(named filename: String) -> Bool {
        documentFileURL(named: filename) != nil
    }

    /// Downsampled, cached image for display in view bodies. ImageIO decodes straight
    /// to the target size, so the full-resolution bitmap is never created, and the
    /// result is cached so SwiftUI re-renders don't hit the disk again.
    /// Filenames are unique UUIDs, so caching by name never serves stale content.
    static func thumbnailFromDocuments(named filename: String, maxPixelSize: CGFloat) -> UIImage? {
        let key = "\(filename)#\(Int(maxPixelSize))" as NSString
        if let cached = thumbnailCache.object(forKey: key) { return cached }
        guard let url = documentFileURL(named: filename),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        else { return nil }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }

        let image = UIImage(cgImage: cgImage)
        thumbnailCache.setObject(image, forKey: key, cost: cgImage.bytesPerRow * cgImage.height)
        return image
    }

    private static let thumbnailCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 80 * 1024 * 1024
        return cache
    }()

    /// Resolves a stored image name/path to an existing file, trying the raw path
    /// first and then the Documents folder (absolute sandbox paths change between installs).
    private static func documentFileURL(named filename: String) -> URL? {
        guard !filename.isEmpty else { return nil }
        let fm = FileManager.default
        if filename.hasPrefix("/"), fm.fileExists(atPath: filename) {
            return URL(fileURLWithPath: filename)
        }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let url = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        return fm.fileExists(atPath: url.path) ? url : nil
    }
}
