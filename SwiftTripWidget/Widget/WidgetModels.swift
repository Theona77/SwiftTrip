//
//  WidgetModels.swift
//  hh / hhWidget  (add to BOTH targets)
//

import Foundation

struct DocumentModel: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var imageName: String
    var note: String
    var startDate: Date?
    var endDate: Date?
    var categoryName: String
}

struct CategoryModel: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var documents: [DocumentModel]
}

struct TripModel: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var startDate: Date
    var endDate: Date
    var description: String
    var imageName: String
    var isSaved: Bool
    var categories: [CategoryModel]
}
