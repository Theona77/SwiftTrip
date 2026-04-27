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

extension TripModel {
    static func makeNew(name: String, startDate: Date, endDate: Date) -> TripModel {
        TripModel(
            name: name,
            startDate: startDate,
            endDate: endDate,
            description: "",
            imageName: "img_banner",
            isSaved: false,
            categories: CategoryModel.defaultCategories
        )
    }
}
