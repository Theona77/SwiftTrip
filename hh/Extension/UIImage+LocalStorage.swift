//
//  UIImage+LocalStorage.swift
//  hh
//
//  Created by Theona Arlinton on 24/04/26.
//

// Ambil gambar dari disk, coba pakai path langsung dulu, kalau gagal coba cari di Documents folder berdasarkan nama file.
// Gambar disimpan di app sandbox, tepatnya di Documents directory.

import UIKit
extension UIImage {
    static func loadFromDocuments(named filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        if let img = UIImage(contentsOfFile: filename) { return img }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        return (try? Data(contentsOf: url)).flatMap(UIImage.init)
    }
}
