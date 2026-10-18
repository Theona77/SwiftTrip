//
//  ScannedDocThumbnail.swift
//  hh
//
//  Created by Theona Arlinton on 24/04/26.
//


//  Menampilkan daftar kecil (grid / horizontal list) dari dokumen scan, di mana user bisa memilih satu.
//  Contoh konteks:
//  - preview beberapa halaman hasil scan
//  - pilih halaman mana yang aktif
//  - switching antar dokumen

import SwiftUI

struct ScannedDocThumbnail: View {
    let doc: ScannedDocument
    let index: Int
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(uiImage: doc.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                    )
                Text("Doc \(index + 1)")
                    .font(.caption2)
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
