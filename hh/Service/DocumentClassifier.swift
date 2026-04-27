//
//  DocumentClassifier.swift
//  hh
//

import Foundation

// MARK: - Document Category

enum DocumentCategory: String, CaseIterable, Identifiable {
    case nationalID     = "National ID"
    case passport       = "Passport"
    case visa           = "VISA"
    case boardingPass   = "Boarding Pass"
    case hotel          = "Hotel"
    case train          = "Trains"
    case reservation    = "Reservations"
    case activity       = "Activities"
    case event          = "Events"
    case other          = "Others"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .nationalID:     return "creditcard.fill"
        case .passport:       return "book.closed.fill"
        case .visa:           return "doc.badge.ellipsis"
        case .boardingPass:   return "airplane.departure"
        case .hotel:          return "bed.double.fill"
        case .train:          return "tram.fill"
        case .reservation:    return "calendar.badge.plus"
        case .activity:       return "figure.hiking"
        case .event:          return "ticket.fill"
        case .other:          return "doc.fill"
        }
    }

    var colorHex: String {
        switch self {
        case .nationalID:     return "#3478F6"
        case .passport:       return "#30B0C7"
        case .visa:           return "#5856D6"
        case .boardingPass:   return "#FF9F0A"
        case .hotel:          return "#FF6B35"
        case .train:          return "#30B0C7"
        case .reservation:    return "#BF5AF2"
        case .activity:       return "#34C759"
        case .event:          return "#FF375F"
        case .other:          return "#8E8E93"
        }
    }

    var isPersonalEssential: Bool {
        switch self {
        case .nationalID, .passport, .visa: return true
        default: return false
        }
    }

    var tripCategoryName: String? {
        switch self {
        case .boardingPass:          return "Flight"
        case .hotel:                 return "Hotel"
        case .train:                 return "Trains"
        case .reservation:           return "Reservations"
        case .activity:              return "Activities"
        case .event:                 return "Events"
        case .other:                 return "Others"
        default:                     return nil
        }
    }
}

// MARK: - Classifier

final class DocumentClassifier {
    static let shared = DocumentClassifier()
    private init() {}

    func classify(data: ExtractedDocumentData) -> DocumentCategory {
        let raw = data.rawText.uppercased()

        // ── Boarding pass — MUST run before passport ─────────────────────
        // Boarding passes often contain passport numbers, so checking
        // "PASPOR" / "PASSPORT" after this would misclassify them.
        if raw.contains("BOARDING PASS") ||
           raw.contains("BOARDING CARD") ||
           raw.contains("KARTU NAIK") ||
           (raw.contains("GATE") && (raw.contains("SEAT") || raw.contains("BOARDING"))) ||
           (data.flightNumber != nil && data.seatNumber != nil) ||
           (data.pnr != nil && data.flightNumber != nil) ||
           (raw.contains("DEPARTURE") && raw.contains("FLIGHT")) {
            return .boardingPass
        }

        // ── Train — before hotel (trains also have check-in-like text) ───
        if raw.contains("KA ") || raw.contains("KERETA") || raw.contains("TRAIN") ||
           raw.contains("RAILINK") || raw.contains("KAI") ||
           raw.contains("STASIUN") ||
           (raw.contains("STATION") && raw.contains("SEAT")) {
            return .train
        }

        // ── Personal identity ────────────────────────────────────────────
        if raw.contains("KARTU TANDA PENDUDUK") ||
           (raw.contains("REPUBLIK INDONESIA") && raw.contains("NIK")) ||
           raw.contains("NATIONAL IDENTITY CARD") ||
           (data.nik != nil && data.nationality != nil) {
            return .nationalID
        }

        if raw.contains("PASSPORT") || raw.contains("PASSEPORT") || raw.contains("PASPOR") {
            return .passport
        }

        if raw.contains("VISA") &&
           (raw.contains("EMBASSY") || raw.contains("CONSULATE") ||
            raw.contains("VALIDITY") || raw.contains("ENTRIES")) {
            return .visa
        }


        // ── Hotel ────────────────────────────────────────────────────────
        if raw.contains("HOTEL") || raw.contains("RESORT") || raw.contains("INN") ||
           raw.contains("CHECK-IN") || raw.contains("CHECK-OUT") ||
           data.hotelName != nil || data.reservationNumber != nil {
            return .hotel
        }

        // ── Events / tickets ─────────────────────────────────────────────
        if raw.contains("ANNUAL PASS") || raw.contains("E-TICKET") ||
           raw.contains("ECARD") || raw.contains("ADMISSION") ||
           raw.contains("CONCERT") || raw.contains("FESTIVAL") ||
           raw.contains("THEME PARK") || raw.contains("DUFAN") ||
           raw.contains("ANCOL") {
            return .event
        }

        // ── Activities ───────────────────────────────────────────────────
        if raw.contains("TOUR") || raw.contains("EXCURSION") ||
           raw.contains("ACTIVITY") || raw.contains("EXPERIENCE") {
            return .activity
        }

        // ── Reservation ──────────────────────────────────────────────────
        if raw.contains("RESERVATION") || raw.contains("BOOKING") ||
           data.bookingCode != nil || data.orderNumber != nil {
            return .reservation
        }

        return .other
    }
}
