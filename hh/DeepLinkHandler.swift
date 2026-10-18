//
//  DeepLinkHandler.swift
//  hh
//

import SwiftUI
import Combine

// MARK: - Destination

enum DeepLinkDestination: Equatable {
    case document(id: String, categoryId: String, tripId: String)
    case category(id: String, tripId: String)
}

// MARK: - Handler

final class DeepLinkHandler: ObservableObject {

    static let shared = DeepLinkHandler()
    private init() {}

    @Published var pendingDestination: DeepLinkDestination?

    func handle(url: URL) {
        guard url.scheme == "hh" else { return }

        // Expected formats:
        //   hh://document/{docId}/{categoryId}/{tripId}
        //   hh://category/{categoryId}/{tripId}
        let parts = url.pathComponents.filter { $0 != "/" }

        switch url.host {
        case "document":
            guard parts.count >= 1 else { return }
            let docId  = parts[0]
            let catId  = parts.count >= 2 ? parts[1] : ""
            let tripId = parts.count >= 3 ? parts[2] : ""
            pendingDestination = .document(id: docId, categoryId: catId, tripId: tripId)

        case "category":
            guard parts.count >= 1 else { return }
            let catId  = parts[0]
            let tripId = parts.count >= 2 ? parts[1] : ""
            pendingDestination = .category(id: catId, tripId: tripId)

        default:
            break
        }
    }
}
