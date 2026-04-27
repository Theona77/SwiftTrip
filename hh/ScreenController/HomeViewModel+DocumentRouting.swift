//
//  HomeViewModel+DocumentRouting.swift
//  hh
//
//  Created by Theona Arlinton on 20/04/26.
//

//
//  HomeViewModel+DocumentRouting.swift
//  hh
//
//  Handles:
//   • Saving personal-essential documents (ID / Passport / VISA / Driving License)
//     directly into the matching globalCategory on the home screen.
//   • Creating an unnamed Trip Card and saving travel documents into the correct
//     category folder inside that trip when no tripID is supplied.
//   • Updating documents inside globalCategories (used by DocumentScreenStandalone).
//

import Foundation
import SwiftUI

extension HomeViewModel {

    // MARK: - Personal Essentials routing
    func addPersonalDocumentToGlobalCategory(_ doc: DocumentModel,
                                             detectedCategory: DocumentCategory) {
        let targetName: String
        switch detectedCategory {
        case .passport:       targetName = "Passport"
        case .visa:           targetName = "VISA"
        default:              targetName = "ID"
        }

        if let idx = globalCategories.firstIndex(where: { $0.name == targetName }) {
            globalCategories[idx].documents.append(doc)
        } else {
            // Safety fallback: create the category if somehow missing.
            let icon = detectedCategory.icon
            var newCat = CategoryModel(name: targetName, icon: icon, documents: [])
            newCat.documents.append(doc)
            globalCategories.append(newCat)
        }
    }

    // MARK: - Auto-created Trip Card routing

    func createTripCard(name: String = "My Trip") -> TripModel {
        let start = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: start) ?? start
        let newTrip = TripModel.makeNew(name: name, startDate: start, endDate: end)
        addTrip(newTrip)
        return newTrip
    }

    /// Creates a new Trip Card with the default seven categories and banner image,
    /// then stores the document in the matching category immediately.
    func createTripCardAndAddDocument(_ doc: DocumentModel,
                                      categoryName: String,
                                      tripName: String = "My Trip") {
        var newTrip = createTripCard(name: tripName)

        if let catIdx = newTrip.categories.firstIndex(where: { $0.name == categoryName }) {
            newTrip.categories[catIdx].documents.append(doc)
        } else {
            let fallbackCategory = CategoryModel(
                name: categoryName,
                icon: iconForCategoryName(categoryName),
                documents: [doc]
            )
            newTrip.categories.append(fallbackCategory)
        }

        guard let tripIdx = trips.firstIndex(where: { $0.id == newTrip.id }) else { return }
        trips[tripIdx] = newTrip
        refreshWidget()
    }

}
