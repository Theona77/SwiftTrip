//
//  ExtensionHomeViewModel.swift
//  hh
//
//  Created by Theona Arlinton on 20/04/26.
//

// 1. Sinkronisasi state global
// Misalnya:
// user edit document di screen lain (DocumentScreenStandalone)
// perubahan harus tercermin di HomeViewModel

import Foundation

extension HomeViewModel {

    /// Update a document inside globalCategories (used by DocumentScreenStandalone)
    func updateDocumentInGlobal(_ doc: DocumentModel, category: CategoryModel) {
        guard
            let cIdx = globalCategories.firstIndex(where: { $0.id == category.id }),
            let dIdx = globalCategories[cIdx].documents.firstIndex(where: { $0.id == doc.id })
        else { return }
        globalCategories[cIdx].documents[dIdx] = doc
    }
}
