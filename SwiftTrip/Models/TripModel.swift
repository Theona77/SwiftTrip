//
//  TripModel.swift
//  hh
//
//  Created by Theona Arlinton on 15/04/26.
//

import SwiftUI
import Foundation

struct DocumentModel: Identifiable, Equatable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var imageName: String
    var note: String
    var startDate: Date?
    var endDate: Date?
    var categoryName: String
    var pdfFilename: String? = nil   // set when source is a PDF
}

struct CategoryModel: Identifiable, Equatable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var documents: [DocumentModel]

    static var defaultCategories: [CategoryModel] {
        [
            CategoryModel(name: "Hotel",        icon: "bed.double.fill",      documents: []),
            CategoryModel(name: "Flight",        icon: "airplane",             documents: []),
            CategoryModel(name: "Trains",        icon: "tram.fill",            documents: []),
            CategoryModel(name: "Reservations",  icon: "calendar.badge.plus",  documents: []),
            CategoryModel(name: "Activities",    icon: "figure.hiking",        documents: []),
            CategoryModel(name: "Events",        icon: "ticket.fill",          documents: []),
            CategoryModel(name: "Others",        icon: "doc.fill",             documents: []),
        ]
    }
}

struct TripModel: Identifiable, Equatable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var startDate: Date
    var endDate: Date
    var description: String
    var imageName: String
    var isSaved: Bool
    var categories: [CategoryModel]

    private var calendar: Calendar { .current }

    private var today: Date {
        calendar.startOfDay(for: Date())
    }

    private var startDay: Date {
        calendar.startOfDay(for: startDate)
    }

    private var endDay: Date {
        calendar.startOfDay(for: endDate)
    }

    var isCompleted: Bool { endDay < today }
    var isUpcoming: Bool { startDay > today }
    var isOngoing: Bool { !isCompleted && !isUpcoming }
    
    var statusColor: Color {
        if isCompleted { return Color(.systemGray) }
        return .blue
    }

    var upcomingOpt: String {
        if isCompleted { return "COMPLETED" }
        if isOngoing { return "ONGOING" }
        return "UPCOMING"
    }

    var allDocuments: [DocumentModel] { categories.flatMap(\.documents) }

    var priorityScore: Int {
        if isOngoing  { return 4 }
        if isSaved    { return 3 }
        if isUpcoming { return 2 }
        return 1
    }

    static let mock1 = TripModel(
        name: "Japan",
        startDate: Calendar.current.date(byAdding: .day, value: 10, to: Date())!,
        endDate:   Calendar.current.date(byAdding: .day, value: 20, to: Date())!,
        description: "Cherry blossom season trip",
        imageName: "img_banner3",
        isSaved: false,
        categories: CategoryModel.defaultCategories
    )

    static let mock2 = TripModel(
        name: "Korea",
        startDate: Calendar.current.date(byAdding: .day, value: -30, to: Date())!,
        endDate:   Calendar.current.date(byAdding: .day, value: -20, to: Date())!,
        description: "K-culture exploration",
        imageName: "img_banner2",
        isSaved: true,
        categories: CategoryModel.defaultCategories
    )
}

// MARK: - Global category placeholder

extension TripModel {
    static var globalPlaceholder: TripModel {
        TripModel(
            name: "",
            startDate: Date(),
            endDate: Date(),
            description: "",
            imageName: "",
            isSaved: false,
            categories: []
        )
    }
}
