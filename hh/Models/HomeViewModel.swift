//
//  HomeViewModel.swift
//  hh
//
//  Changes from previous version
//  ──────────────────────────────
//  • After any mutation that could change which document the widget shows,
//    we call SharedDocumentStore.shared.updateWidgetSnapshot(…) + WidgetCenter.reloadAll().
//  • recordRecentDocument triggers a widget refresh.
//

import SwiftUI
import Combine
import WidgetKit
import Foundation

class HomeViewModel: ObservableObject {
    @Published var trips: [TripModel] {
        didSet { persistAppState() }
    }
    @Published var searchText: String = ""
    @Published var personalDocuments: [DocumentModel] {
        didSet { persistAppState() }
    }

    @Published var recentDocuments: [DocumentModel] {
        didSet { persistAppState() }
    }

    @Published var globalCategories: [CategoryModel] {
        didSet { persistAppState() }
    }

    // Data disimpan ke: ApplicationSupport/HomeState/home_state.json
    private struct PersistedHomeState: Codable {
        var trips: [TripModel]
        var personalDocuments: [DocumentModel]
        var recentDocuments: [DocumentModel]
        
        // kategori umum (ID, Passport, VISA), tidak terkait trip
        var globalCategories: [CategoryModel]
    }

    private static let defaultGlobalCategories: [CategoryModel] = [
        CategoryModel(name: "ID",       icon: "person.text.rectangle", documents: []),
        CategoryModel(name: "Passport", icon: "book.closed",           documents: []),
        CategoryModel(name: "VISA",     icon: "doc.text",              documents: [])
    ]

    
    // Jika + trip, load dari disk
    init() {
        if let state = Self.loadPersistedState() {
            self.trips = state.trips
            self.personalDocuments = state.personalDocuments
            self.recentDocuments = state.recentDocuments
            self.globalCategories = state.globalCategories
        } else {
            self.trips = [.mock1, .mock2]
            self.personalDocuments = []
            self.recentDocuments = []
            self.globalCategories = Self.defaultGlobalCategories
        }

        refreshWidget()
    }

    // MARK: - Recent documents
    func recordRecentDocument(_ doc: DocumentModel) {
        recentDocuments.removeAll { $0.id == doc.id }
        recentDocuments.insert(doc, at: 0)
        if recentDocuments.count > 10 {
            recentDocuments = Array(recentDocuments.prefix(10))
        }
        refreshWidget()
    }

    // MARK: - Sorted / filtered trips
    // Berdasarkan priority score
    var sortedTrips: [TripModel] {
        trips.sorted {
            if $0.priorityScore == $1.priorityScore {
                return $0.startDate < $1.startDate
            }
            return $0.priorityScore > $1.priorityScore
        }
    }

    var filteredTrips: [TripModel] {
        sortedTrips
    }

    var nearestTripID: UUID? {
        let now = Date()
        return trips
            .sorted {
                score(for: $0, now: now) < score(for: $1, now: now)
            }
            .first?.id
    }

    //    Ambil semua dokumen dari trip
    //    berdasarkan tanggal (paling dekat dulu)
    //    kalau sama → berdasarkan nama
    var allDocuments: [DocumentModel] {
        let tripDocs = trips.flatMap { $0.categories.flatMap(\.documents) }
        let globalDocs = globalCategories.flatMap(\.documents)

        return (tripDocs + globalDocs).sorted { lhs, rhs in
            let lhsDate = lhs.startDate ?? lhs.endDate ?? .distantFuture
            let rhsDate = rhs.startDate ?? rhs.endDate ?? .distantFuture
            if lhsDate == rhsDate {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhsDate < rhsDate
        }
    }

    // menghasilkan daftar dokumen yang sesuai dengan teks pencarian (searchText).
    //    dokumen akan masuk hasil kalau:
    //    nama dokumen cocok
    //    ATAU nama kategori cocok
    //    ATAU catatan (note) cocok
    var filteredDocuments: [DocumentModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return allDocuments }

        return allDocuments.filter { doc in
            doc.name.localizedCaseInsensitiveContains(query)
            || doc.categoryName.localizedCaseInsensitiveContains(query)
            || doc.note.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Trip CRUD

    func addTrip(_ trip: TripModel) {
        trips.append(trip)
        refreshWidget()
    }

    func removeTrip(_ trip: TripModel) {
        trips.removeAll { $0.id == trip.id }
        refreshWidget()
    }

    func toggleSaved(for trip: TripModel) {
        guard let idx = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[idx].isSaved.toggle()
    }

    func renameTrip(_ trip: TripModel, to name: String) {
        guard let idx = trips.firstIndex(where: { $0.id == trip.id }),
              !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        trips[idx].name = name
    }

    func updateTripDescription(_ trip: TripModel, to description: String) {
        guard let idx = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[idx].description = description
    }

    // MARK: - Category CRUD

    func addCategory(_ category: CategoryModel, to trip: TripModel) {
        guard let idx = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[idx].categories.append(category)
    }

    func removeCategory(_ category: CategoryModel, from trip: TripModel) {
        guard let tIdx = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[tIdx].categories.removeAll { $0.id == category.id }
    }

    func moveCategories(in trip: TripModel, from source: IndexSet, to destination: Int) {
        guard let tIdx = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[tIdx].categories.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Document CRUD

    func addDocument(_ doc: DocumentModel, to category: CategoryModel, in trip: TripModel) {
        guard
            let tIdx = trips.firstIndex(where: { $0.id == trip.id }),
            let cIdx = trips[tIdx].categories.firstIndex(where: { $0.id == category.id })
        else { return }
        trips[tIdx].categories[cIdx].documents.append(doc)
        refreshWidget()
    }

    func addDocument(_ doc: DocumentModel,
                     toCategoryNamed catName: String,
                     inTripID tripID: UUID) {
        guard let tripIdx = trips.firstIndex(where: { $0.id == tripID }) else { return }
        if let catIdx = trips[tripIdx].categories.firstIndex(where: { $0.name == catName }) {
            trips[tripIdx].categories[catIdx].documents.append(doc)
        } else {
            var newCat = CategoryModel(name: catName,
                                       icon: iconForCategoryName(catName),
                                       documents: [])
            newCat.documents.append(doc)
            trips[tripIdx].categories.append(newCat)
        }
        refreshWidget()
    }

    func updateDocument(_ doc: DocumentModel, in category: CategoryModel, trip: TripModel) {
        guard
            let tIdx = trips.firstIndex(where: { $0.id == trip.id }),
            let cIdx = trips[tIdx].categories.firstIndex(where: { $0.id == category.id }),
            let dIdx = trips[tIdx].categories[cIdx].documents.firstIndex(where: { $0.id == doc.id })
        else { return }
        trips[tIdx].categories[cIdx].documents[dIdx] = doc
        // Sync recents so HomeScreen updates immediately
        if let rIdx = recentDocuments.firstIndex(where: { $0.id == doc.id }) {
            recentDocuments[rIdx] = doc
        }
        refreshWidget()
    }

    func addPersonalDocument(_ doc: DocumentModel) {
        personalDocuments.append(doc)
        refreshWidget()
    }

    func addDocumentToGlobal(_ doc: DocumentModel, category: CategoryModel) {
        if let index = globalCategories.firstIndex(where: { $0.id == category.id }) {
            globalCategories[index].documents.append(doc)
            refreshWidget()
        }
    }
    
    // MARK: - Document removal
    
    func deleteDocument(_ doc: DocumentModel) {
        
        // 1. Delete image file
        if !doc.imageName.isEmpty {
            removeImageFile(named: doc.imageName)
        }
        if let pdf = doc.pdfFilename {
            removeImageFile(named: pdf)
        }

        // 2. Remove from ALL trips
        for tIdx in trips.indices {
            for cIdx in trips[tIdx].categories.indices {
                trips[tIdx].categories[cIdx].documents.removeAll {
                    $0.id == doc.id
                }
            }
        }

        // 3. Remove from ALL global categories (ID, Passport, VISA)
        for cIdx in globalCategories.indices {
            globalCategories[cIdx].documents.removeAll {
                $0.id == doc.id
            }
        }

        // 4. Remove from recents
        recentDocuments.removeAll { $0.id == doc.id }

        // 5. Remove from personal documents (if used)
        personalDocuments.removeAll { $0.id == doc.id }

        // 6. Refresh widget
        refreshWidget()
    }
    
    

    func removeDocument(_ doc: DocumentModel, from category: CategoryModel, in trip: TripModel) {
        guard
            let tIdx = trips.firstIndex(where: { $0.id == trip.id }),
            let cIdx = trips[tIdx].categories.firstIndex(where: { $0.id == category.id })
        else { return }
        trips[tIdx].categories[cIdx].documents.removeAll { $0.id == doc.id }
        recentDocuments.removeAll { $0.id == doc.id }
        refreshWidget()
    }

    func removeDocumentFromGlobal(_ doc: DocumentModel, category: CategoryModel) {
        guard let cIdx = globalCategories.firstIndex(where: { $0.id == category.id }) else { return }
        globalCategories[cIdx].documents.removeAll { $0.id == doc.id }
        recentDocuments.removeAll { $0.id == doc.id }
        refreshWidget()
    }

    func removeImageFile(named filename: String) {
        guard !filename.isEmpty else { return }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }

    func updateTripDates(_ trip: TripModel, startDate: Date, endDate: Date) {
        guard let idx = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[idx].startDate = startDate
        trips[idx].endDate = endDate
    }

    // MARK: - Widget refresh

    func refreshWidget() {
        SharedDocumentStore.shared.updateWidgetSnapshot(
            trips: trips,
            globalCategories: globalCategories,
            recentDocuments: recentDocuments      // ← pass recents so widget shows last viewed
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Private helpers

    func iconForCategoryName(_ name: String) -> String {
        switch name.lowercased() {
        case "flight", "boarding pass": return "airplane"
        case "hotel":                   return "bed.double.fill"
        case "trains":                  return "tram.fill"
        case "reservations":            return "calendar.badge.plus"
        case "activities":              return "figure.hiking"
        case "events":                  return "ticket.fill"
        default:                        return "doc.fill"
        }
    }

    private func score(for trip: TripModel, now: Date) -> TimeInterval {
        if trip.startDate <= now && trip.endDate >= now {
            return 0
        }
        if trip.startDate > now {
            return trip.startDate.timeIntervalSince(now)
        }
        return now.timeIntervalSince(trip.endDate) + 1_000_000
    }

    private func persistAppState() {
        let state = PersistedHomeState(
            trips: trips,
            personalDocuments: personalDocuments,
            recentDocuments: recentDocuments,
            globalCategories: globalCategories
        )

        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: Self.persistenceURL, options: .atomic)
    }

    private static func loadPersistedState() -> PersistedHomeState? {
        guard
            let data = try? Data(contentsOf: persistenceURL),
            let state = try? JSONDecoder().decode(PersistedHomeState.self, from: data)
        else { return nil }
        return state
    }

    private static var persistenceURL: URL {
        let baseURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("HomeState", isDirectory: true)

        try? FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )

        return baseURL.appendingPathComponent("home_state.json")
    }
}
