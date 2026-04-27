//
//  TripModel+Factory.swift
//  hh
//
//  Created by Theona Arlinton on 20/04/26.
//

//
//  TripModel+Factory.swift
//  hh
//
//  Adds a static factory so routing code can create TripModel values
//  without duplicating the initialiser call everywhere.
//

import Foundation
import UIKit

extension TripModel {
    static func makeNew(name: String, startDate: Date, endDate: Date, description: String = "") -> TripModel {
        TripModel(
            name: name,
            startDate: startDate,
            endDate: endDate,
            description: description,
            imageName: randomBannerImageName(),
            isSaved: false,
            categories: CategoryModel.defaultCategories
        )
    }

    private static func randomBannerImageName() -> String {
        let key = "used_banner_images"

        let candidateNames = ["img_banner"] + (1...12).map { "img_banner\($0)" }
        let availableNames = candidateNames.filter { UIImage(named: $0) != nil }

        guard !availableNames.isEmpty else {
            return "img_banner"
        }

        let defaults = UserDefaults.standard
        var used = defaults.stringArray(forKey: key) ?? []

        // Filter unused images
        let unused = availableNames.filter { !used.contains($0) }

        let selected: String

        if let pick = unused.randomElement() {
            // Still have unused images
            selected = pick
            used.append(pick)
        } else {
            // All used → reset cycle
            used = []
            selected = availableNames.randomElement()!
            used.append(selected)
        }

        defaults.set(used, forKey: key)
        return selected
    }
}
