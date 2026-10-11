//
//  DocumentAIAssistant.swift
//  hh
//
//  Second opinion from Apple's on-device language model (Foundation Models,
//  iOS 26+, Apple Intelligence devices). Rules always run first; the model is
//  only asked when the rules are unsure or key fields are missing, and it can
//  read documents in languages our keyword lists don't cover.
//
//  • Rule results that are confident are never overridden.
//  • Model fields only fill gaps, and are accepted only if every word of the
//    value actually appears in the OCR text (guards against hallucination).
//  • Unavailable device / OS, unsupported language, timeout or any error →
//    the rule result is kept unchanged.
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

final class DocumentAIAssistant {

    static let shared = DocumentAIAssistant()
    private init() {}

    /// Seconds before giving up and keeping the rule result.
    private let timeout: Double = 10

    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Whether the rule result is worth a second opinion.
    func shouldAssist(_ data: ExtractedDocumentData, rules: DocumentClassification) -> Bool {
        guard isAvailable, data.rawText.count > 10 else { return false }
        if rules.confidence < DocumentClassifier.confidentThreshold || rules.category == .other {
            return true
        }
        return !missingKeyFields(for: rules.category, in: data).isEmpty
    }

    /// Fields a user expects for each category.
    private func missingKeyFields(for category: DocumentCategory,
                                  in d: ExtractedDocumentData) -> [String] {
        var missing: [String] = []
        func need(_ name: String, _ value: String?) { if value == nil { missing.append(name) } }
        switch category {
        case .nationalID, .passport, .visa:
            need("fullName", d.fullName); need("documentNumber", d.documentNumber ?? d.nik)
        case .boardingPass:
            need("flightNumber", d.flightNumber); need("date", d.date)
        case .train:
            need("date", d.date); need("origin", d.origin)
        case .hotel:
            need("hotelName", d.hotelName); need("date", d.date)
        case .reservation, .activity, .event:
            need("date", d.date)
        case .other:
            break
        }
        return missing
    }

    /// Returns the refined data and classification, or the inputs unchanged.
    func refine(_ data: ExtractedDocumentData,
                rules: DocumentClassification) async -> (ExtractedDocumentData, DocumentClassification) {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAvailable,
           let analysis = await analyse(data.rawText) {
            return merge(analysis, into: data, rules: rules)
        }
        #endif
        return (data, rules)
    }
}

#if canImport(FoundationModels)

// MARK: - Model output schema

@available(iOS 26.0, *)
@Generable
nonisolated struct GeneratedDocumentAnalysis {
    @Guide(description: "The document type.",
           .anyOf(["nationalID", "passport", "visa", "boardingPass", "hotel",
                   "train", "reservation", "activity", "event", "other"]))
    var category: String

    @Guide(description: "Full name of the holder, passenger or guest, copied exactly as written.")
    var fullName: String?

    @Guide(description: "Passport, ID card or visa number, copied exactly.")
    var documentNumber: String?

    @Guide(description: "Date of birth, copied exactly as written.")
    var dateOfBirth: String?

    @Guide(description: "Expiry or valid-until date, copied exactly as written.")
    var expiryDate: String?

    @Guide(description: "Nationality or issuing country, copied exactly.")
    var nationality: String?

    @Guide(description: "Booking code, PNR, confirmation or reservation number, copied exactly.")
    var bookingCode: String?

    @Guide(description: "Flight number such as GA 410, copied exactly.")
    var flightNumber: String?

    @Guide(description: "Seat number such as 23A.")
    var seatNumber: String?

    @Guide(description: "Departure city, station or airport.")
    var origin: String?

    @Guide(description: "Arrival city, station or airport.")
    var destination: String?

    @Guide(description: "Main travel, check-in or event date, copied exactly as written.")
    var date: String?

    @Guide(description: "Departure, check-in or start time, e.g. 08:35.")
    var time: String?

    @Guide(description: "Hotel or property name.")
    var hotelName: String?

    @Guide(description: "Short title of the document, e.g. the airline, venue or issuing country.")
    var documentTitle: String?
}

// MARK: - Model call

@available(iOS 26.0, *)
extension DocumentAIAssistant {

    private static let instructions = """
    You read OCR text from travel documents. The text may be in any language \
    and may contain OCR mistakes. Classify the document and extract its fields.
    Categories:
    - nationalID: national identity card (KTP, MyKad, Personalausweis …)
    - passport: passport data page
    - visa: visa sticker, e-visa or visa approval
    - boardingPass: airline boarding pass or flight e-ticket
    - hotel: hotel, villa, hostel or apartment booking / voucher
    - train: train ticket or train boarding pass
    - reservation: restaurant, car rental or other reservation
    - activity: tour, excursion, class or experience voucher
    - event: concert, festival, theme park, museum or sports ticket
    - other: anything else (receipts, insurance, notes …)
    Copy field values exactly as they appear in the text. If a field is not \
    present, leave it empty. Never guess or invent values.
    """

    fileprivate func analyse(_ rawText: String) async -> GeneratedDocumentAnalysis? {
        // The on-device model has a small context window — keep the prompt short.
        let text = String(rawText.prefix(2500))
        let session = LanguageModelSession(instructions: Self.instructions)
        let prompt = "Document text:\n\(text)"

        let work = Task {
            try await session.respond(to: prompt,
                                      generating: GeneratedDocumentAnalysis.self,
                                      options: GenerationOptions(sampling: .greedy))
        }
        let seconds = timeout
        let timeoutTask = Task {
            try? await Task.sleep(for: .seconds(seconds))
            work.cancel()
        }
        defer { timeoutTask.cancel() }

        do {
            return try await work.value.content
        } catch {
            // Unsupported language, guardrail, context overflow, cancellation …
            return nil
        }
    }

    fileprivate func merge(_ a: GeneratedDocumentAnalysis,
                           into data: ExtractedDocumentData,
                           rules: DocumentClassification) -> (ExtractedDocumentData, DocumentClassification) {
        var d = data
        let raw = data.rawText

        // Only fill gaps, and only with values that really appear in the text.
        func fill(_ keyPath: WritableKeyPath<ExtractedDocumentData, String?>, _ value: String?) {
            guard d[keyPath: keyPath] == nil,
                  let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !value.isEmpty, value.appears(in: raw) else { return }
            d[keyPath: keyPath] = value
        }
        fill(\.fullName,       a.fullName)
        fill(\.documentNumber, a.documentNumber)
        fill(\.dateOfBirth,    a.dateOfBirth)
        fill(\.expiryDate,     a.expiryDate)
        fill(\.nationality,    a.nationality)
        fill(\.bookingCode,    a.bookingCode)
        fill(\.flightNumber,   a.flightNumber)
        fill(\.seatNumber,     a.seatNumber)
        fill(\.origin,         a.origin)
        fill(\.destination,    a.destination)
        fill(\.date,           a.date)
        fill(\.time,           a.time)
        fill(\.hotelName,      a.hotelName)
        fill(\.documentTitle,  a.documentTitle)

        // Confident rules win; otherwise take the model's category.
        var result = rules
        if rules.confidence < DocumentClassifier.confidentThreshold || rules.category == .other,
           let category = DocumentCategory(trainingLabel: a.category) {
            let agrees = category == rules.category
            result = DocumentClassification(category: category,
                                            confidence: agrees ? max(rules.confidence, 0.8) : 0.7,
                                            source: .foundationModel)
        }
        return (d, result)
    }
}

#endif

// MARK: - Hallucination guard

private extension String {
    /// True if every word of `self` occurs in `text` (case-insensitive,
    /// ignoring punctuation and spacing).
    func appears(in text: String) -> Bool {
        let haystack = text.uppercased().filter { $0.isLetter || $0.isNumber }
        let words = uppercased()
            .split(whereSeparator: { !($0.isLetter || $0.isNumber) })
            .map(String.init)
        guard !words.isEmpty else { return false }
        return words.allSatisfy { haystack.contains($0) }
    }
}
