//
//  RootView.swift
//  hh
//

import SwiftUI

// Wrapper so NavigationStack can push a typed destination
enum AppDestination: Hashable {
    case category(CategoryModel, TripModel)
    case document(DocumentModel, CategoryModel, TripModel)
}

struct RootView: View {
    @AppStorage("hasOnboarded") private var hasOnboarded = false
    @EnvironmentObject var deepLinkHandler: DeepLinkHandler
    @EnvironmentObject var vm: HomeViewModel

    @State private var showScanner = false
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            if !hasOnboarded {
                BoardingScreen {
                    hasOnboarded = true
                }
            } else {
                NavigationStack(path: $navigationPath) {
                    HomeScreen()
                        .navigationDestination(for: AppDestination.self) { dest in
                            switch dest {
                            case .category(let cat, let trip):
                                CategoryScreen(category: cat, trip: trip)
                            case .document(let doc, let cat, let trip):
                                DocumentScreen(document: doc, category: cat, trip: trip)
                            }
                        }
                }
                .sheet(isPresented: $showScanner) {
                    Text("Camera / Scanner View Here")
                }
            }
        }
        .onChange(of: deepLinkHandler.pendingDestination) { _, destination in
            guard let destination else { return }
            handleDeepLink(destination)
            deepLinkHandler.pendingDestination = nil
        }
    }

    // MARK: - Deep link routing

    private func handleDeepLink(_ destination: DeepLinkDestination) {
        switch destination {

        case .category(let categoryId, let tripId):
            guard let (cat, trip) = resolveCategory(categoryId: categoryId, tripId: tripId)
            else { return }
            navigationPath.append(AppDestination.category(cat, trip))

        case .document(let docId, let categoryId, let tripId):
            guard let (doc, cat, trip) = resolveDocument(docId: docId, categoryId: categoryId, tripId: tripId)
            else { return }
            // Push category then document so back-navigation works naturally
            navigationPath.append(AppDestination.category(cat, trip))
            navigationPath.append(AppDestination.document(doc, cat, trip))

        case .scan:
            showScanner = true
        }
    }

    private func resolveCategory(categoryId: String, tripId: String) -> (CategoryModel, TripModel)? {
        if tripId.isEmpty {
            // Global category — use first trip as context (or create a dummy)
            guard let cat = vm.globalCategories.first(where: { $0.id.uuidString == categoryId })
            else { return nil }
            // Global categories don't belong to a trip; pass first available trip or a placeholder
            let trip = vm.trips.first ?? TripModel.globalPlaceholder
            return (cat, trip)
        }
        guard
            let trip = vm.trips.first(where: { $0.id.uuidString == tripId }),
            let cat  = trip.categories.first(where: { $0.id.uuidString == categoryId })
        else { return nil }
        return (cat, trip)
    }

    private func resolveDocument(docId: String,
                                 categoryId: String,
                                 tripId: String) -> (DocumentModel, CategoryModel, TripModel)? {
        if tripId.isEmpty {
            for cat in vm.globalCategories {
                if let doc = cat.documents.first(where: { $0.id.uuidString == docId }) {
                    let trip = vm.trips.first ?? TripModel.globalPlaceholder
                    return (doc, cat, trip)
                }
            }
            return nil
        }
        guard let trip = vm.trips.first(where: { $0.id.uuidString == tripId }) else { return nil }
        for cat in trip.categories {
            if let doc = cat.documents.first(where: { $0.id.uuidString == docId }) {
                return (doc, cat, trip)
            }
        }
        return nil
    }
}
