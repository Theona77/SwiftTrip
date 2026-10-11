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

    /// Stable label used in the Create ML training data and model output.
    /// Don't rename these — a trained model depends on them.
    var trainingLabel: String {
        switch self {
        case .nationalID:     return "nationalID"
        case .passport:       return "passport"
        case .visa:           return "visa"
        case .boardingPass:   return "boardingPass"
        case .hotel:          return "hotel"
        case .train:          return "train"
        case .reservation:    return "reservation"
        case .activity:       return "activity"
        case .event:          return "event"
        case .other:          return "other"
        }
    }

    init?(trainingLabel: String) {
        guard let match = DocumentCategory.allCases.first(where: { $0.trainingLabel == trainingLabel })
        else { return nil }
        self = match
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

// MARK: - Classification result

struct DocumentClassification {
    enum Source { case mrz, rule, model, keywords, foundationModel }

    let category: DocumentCategory
    /// 0…1. Below `DocumentClassifier.confidentThreshold` the UI should
    /// ask the user to confirm the category.
    let confidence: Double
    let source: Source
}

// MARK: - Classifier
//
// Pipeline:
//   1. MRZ (check-digit verified)          → passport / visa / ID, ~certain
//   2. Unambiguous phrases                  → e.g. "BOARDING PASS", "KARTU TANDA PENDUDUK"
//   3. Create ML text classifier (if bundled and confident)
//   4. Weighted whole-word keyword scoring  → fallback, or "Others" when weak
//   5. (async, ScanStore) Apple Foundation Models refines low-confidence results
//      and fills missing fields — see DocumentAIAssistant

final class DocumentClassifier {
    static let shared = DocumentClassifier()
    private init() {}

    static let confidentThreshold = 0.6

    func classify(data: ExtractedDocumentData) -> DocumentCategory {
        classifyWithConfidence(data: data).category
    }

    func classifyWithConfidence(data: ExtractedDocumentData) -> DocumentClassification {
        let text = KeywordText(data.rawText)

        // ── 1. MRZ ───────────────────────────────────────────────────────
        if let mrz = data.mrz {
            let category: DocumentCategory
            switch mrz.kind {
            case .passport: category = .passport
            case .visa:     category = .visa
            case .idCard:   category = .nationalID
            }
            return DocumentClassification(category: category,
                                          confidence: mrz.isValid ? 0.99 : 0.85,
                                          source: .mrz)
        }

        // ── 2. Unambiguous phrases ───────────────────────────────────────
        // Boarding passes often print the passport number, so this runs
        // before any passport keyword can win.
        if text.containsAny(["BOARDING PASS", "BOARDING CARD", "KARTU NAIK", "KARTU NAIK PESAWAT"]) {
            // KAI / Whoosh train tickets are also titled "Boarding Pass".
            let isTrain = text.containsAny(["KERETA", "KERETA API", "KAI", "KCIC", "WHOOSH", "RAILINK",
                                            "STASIUN", "GERBONG", "TRAIN", "RAILWAY", "SHINKANSEN"])
            return DocumentClassification(category: isTrain ? .train : .boardingPass,
                                          confidence: 0.95, source: .rule)
        }
        if text.containsAny(["KARTU TANDA PENDUDUK", "NATIONAL IDENTITY CARD"]) ||
           (data.nik != nil && text.containsAny(["PROVINSI", "KECAMATAN", "AGAMA"])) {
            return DocumentClassification(category: .nationalID, confidence: 0.95, source: .rule)
        }

        // ── 3. Create ML model ───────────────────────────────────────────
        let keywordResult = keywordScore(text: text, data: data)
        if let prediction = DocumentTextClassifier.shared.predict(data.rawText) {
            if prediction.confidence >= Self.confidentThreshold {
                return DocumentClassification(category: prediction.category,
                                              confidence: prediction.confidence,
                                              source: .model)
            }
            // Model unsure: prefer keywords if they agree or are strong.
            if keywordResult.category == prediction.category {
                return DocumentClassification(category: prediction.category,
                                              confidence: max(prediction.confidence, keywordResult.confidence),
                                              source: .model)
            }
        }

        // ── 4. Keyword scoring ───────────────────────────────────────────
        return keywordResult
    }

    // MARK: - Keyword scoring

    /// (phrase, weight). Phrases match on whole words only.
    private static let keywords: [DocumentCategory: [(String, Double)]] = [
        .boardingPass: [("登机牌", 5), ("搭乗券", 5), ("탑승권", 5), ("ПОСАДОЧНЫЙ ТАЛОН", 5), ("CARTE D EMBARQUEMENT", 5), ("TARJETA DE EMBARQUE", 5), ("BORDKARTE", 5), ("BOARDING TIME", 3), ("GATE", 2), ("FLIGHT", 2), ("PENERBANGAN", 2),
                        ("SEAT", 1), ("DEPARTURE", 1), ("ARRIVAL", 1), ("TERMINAL", 1),
                        ("BOARDING", 2), ("ZONE", 0.5), ("CLASS", 0.5), ("AIRLINES", 1),
                        ("AIRWAYS", 1), ("AIRPORT", 1), ("BANDARA", 1)],
        .train:        [("新幹線", 4), ("列車", 3), ("火车", 3), ("高铁", 4), ("動車", 3), ("기차", 3), ("열차", 3), ("KTX", 4), ("ПОЕЗД", 3), ("ZUG", 2), ("TRENO", 3), ("TREN", 3), ("GARE", 2), ("KERETA API", 4), ("KERETA", 3), ("KAI", 2), ("TRAIN", 3),
                        ("RAILWAY", 3), ("RAILINK", 4), ("STASIUN", 3), ("STATION", 1.5),
                        ("GERBONG", 3), ("CARRIAGE", 2), ("CAR NO", 1), ("COACH", 1),
                        ("SHINKANSEN", 4), ("KCIC", 4), ("WHOOSH", 4), ("KRL", 3),
                        ("EKSEKUTIF", 1), ("EKONOMI", 1)],
        .nationalID:   [("身分証明書", 4), ("身份证", 4), ("居民身份证", 5), ("주민등록증", 5), ("CARTE NATIONALE D IDENTITE", 5), ("PERSONALAUSWEIS", 5), ("DOCUMENTO NACIONAL DE IDENTIDAD", 5), ("CARTA D IDENTITA", 5), ("MYKAD", 5), ("NIK", 2), ("PROVINSI", 2), ("KABUPATEN", 1.5), ("KECAMATAN", 2),
                        ("KEL DESA", 2), ("RT RW", 2), ("AGAMA", 2), ("GOL DARAH", 2),
                        ("STATUS PERKAWINAN", 2), ("PEKERJAAN", 1.5), ("IDENTITY CARD", 4),
                        ("ID CARD", 3), ("RESIDENT", 1)],
        .passport:     [("PASAPORTE", 4), ("PASSAPORTO", 4), ("PASPOORT", 4), ("PASZPORT", 4), ("ПАСПОРТ", 4), ("旅券", 4), ("护照", 4), ("護照", 4), ("여권", 4), ("جواز سفر", 4), ("หนังสือเดินทาง", 4), ("PASSPORT", 4), ("PASPOR", 4), ("PASSEPORT", 4), ("REISEPASS", 3),
                        ("PLACE OF BIRTH", 1), ("DATE OF ISSUE", 1), ("ISSUING AUTHORITY", 1),
                        ("AUTHORITY", 0.5), ("SURNAME", 1), ("GIVEN NAMES", 1)],
        .visa:         [("VISUM", 3), ("VISADO", 3), ("ビザ", 3), ("签证", 3), ("簽證", 3), ("사증", 3), ("비자", 3), ("ВИЗА", 3), ("VISA", 3), ("EMBASSY", 2), ("CONSULATE", 2), ("ENTRIES", 2),
                        ("NUMBER OF ENTRIES", 2), ("VALIDITY", 1), ("DURATION OF STAY", 2),
                        ("VISA TYPE", 2), ("IMMIGRATION", 1.5), ("IMIGRASI", 1.5),
                        ("VISA ON ARRIVAL", 3), ("EVISA", 3)],
        .hotel:        [("ホテル", 3), ("호텔", 3), ("酒店", 3), ("飯店", 3), ("宾馆", 3), ("旅館", 3), ("ОТЕЛЬ", 3), ("ГОСТИНИЦА", 3), ("HÔTEL", 3), ("ALBERGO", 3), ("CHAMBRE", 1.5), ("HABITACIÓN", 1.5), ("HOTEL", 3), ("RESORT", 3), ("INN", 1.5), ("HOSTEL", 3), ("VILLA", 2),
                        ("CHECK IN", 2), ("CHECK OUT", 2), ("ROOM", 1.5), ("ROOM TYPE", 2),
                        ("GUEST", 1), ("NIGHTS", 2), ("NIGHT", 1), ("BREAKFAST", 1),
                        ("ACCOMMODATION", 3), ("PENGINAPAN", 3), ("KAMAR", 1.5),
                        ("AIRBNB", 3), ("HOST", 1)],
        .event:        [("コンサート", 3), ("콘서트", 3), ("演唱会", 3), ("入場券", 3), ("门票", 3), ("입장권", 3), ("BILLET", 1.5), ("ENTRADA", 1.5), ("E TICKET", 1.5), ("ADMISSION", 2), ("CONCERT", 3), ("KONSER", 3),
                        ("FESTIVAL", 3), ("THEME PARK", 3), ("DUFAN", 3), ("ANCOL", 2),
                        ("ANNUAL PASS", 3), ("ECARD", 2), ("VENUE", 2), ("STAGE", 1),
                        ("TIKET MASUK", 3), ("ENTRY TICKET", 3), ("MUSEUM", 2),
                        ("STADIUM", 2), ("SHOW", 1), ("MATCH", 1), ("EXHIBITION", 2),
                        ("PAMERAN", 2), ("SECTION", 1), ("ROW", 0.5)],
        .activity:     [("TOUR", 2), ("TOURS", 2), ("EXCURSION", 3), ("ACTIVITY", 2),
                        ("EXPERIENCE", 1.5), ("SNORKELING", 3), ("DIVING", 3), ("HIKING", 3),
                        ("TREKKING", 3), ("RAFTING", 3), ("WORKSHOP", 2), ("CLASS", 0.5),
                        ("MEETING POINT", 2), ("PICKUP", 1), ("PICK UP", 1), ("GUIDE", 1),
                        ("SAFARI", 2), ("CRUISE", 2), ("SPA", 2)],
        .reservation:  [("RESERVATION", 2), ("RESERVASI", 2), ("BOOKING", 1),
                        ("CONFIRMATION", 1), ("RESTAURANT", 3), ("RESTORAN", 3),
                        ("TABLE", 1.5), ("PARTY SIZE", 2), ("GUESTS", 0.5),
                        ("CAR RENTAL", 3), ("RENTAL", 1.5), ("SEWA", 1.5)],
    ]

    /// Minimum score for keyword scoring to commit to a category.
    private static let minimumScore = 3.0

    private func keywordScore(text: KeywordText, data: ExtractedDocumentData) -> DocumentClassification {
        var scores: [DocumentCategory: Double] = [:]
        for (category, phrases) in Self.keywords {
            scores[category] = phrases.reduce(0) { $0 + (text.contains($1.0) ? $1.1 : 0) }
        }

        // Structured fields add evidence.
        if data.flightNumber != nil                          { scores[.boardingPass, default: 0] += 1.5 }
        if data.flightNumber != nil && data.seatNumber != nil { scores[.boardingPass, default: 0] += 2 }
        if data.pnr != nil                                   { scores[.boardingPass, default: 0] += 1 }
        if data.nik != nil                                   { scores[.nationalID, default: 0] += 3 }
        if data.hotelName != nil                             { scores[.hotel, default: 0] += 2 }
        if data.bookingCode != nil || data.orderNumber != nil ||
           data.reservationNumber != nil                     { scores[.reservation, default: 0] += 1 }

        let ranked = scores.sorted { $0.value > $1.value }
        guard let best = ranked.first, best.value >= Self.minimumScore else {
            return DocumentClassification(category: .other, confidence: 0.5, source: .keywords)
        }
        let runnerUp = ranked.dropFirst().first?.value ?? 0
        // Margin-based confidence: a clear winner approaches 1, a tie is ~0.5.
        let confidence = min(0.9, best.value / (best.value + runnerUp + 1))
        return DocumentClassification(category: best.key, confidence: confidence, source: .keywords)
    }
}

// MARK: - Keyword text

/// OCR text reduced to uppercase words separated by single spaces, so
/// phrases match on word boundaries ("INN" ≠ "DINNER", "KAI" ≠ "MIKAIL").
struct KeywordText {
    private let padded: String

    init(_ raw: String) {
        let words = raw.uppercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
        padded = " " + words.joined(separator: " ") + " "
    }

    func contains(_ phrase: String) -> Bool {
        // Scripts written without spaces (Chinese, Japanese, Thai …) can't use
        // word boundaries, so match those as plain substrings.
        if phrase.unicodeScalars.contains(where: { $0.value >= 0x0E00 && !(0x1E00...0x1EFF).contains($0.value) }) {
            return padded.contains(phrase)
        }
        return padded.contains(" " + phrase + " ")
    }

    func containsAny(_ phrases: [String]) -> Bool {
        phrases.contains { self.contains($0) }
    }
}
