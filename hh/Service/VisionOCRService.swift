//
//  VisionOCRService.swift
//  hh
//

import Vision
import UIKit

// MARK: - Extracted Document Data

struct ExtractedDocumentData {
    var rawText: String = ""
    var isBoardingPass: Bool = false

    // Identity
    var fullName: String?
    var dateOfBirth: String?
    var expiryDate: String?
    var documentNumber: String?
    var nationality: String?
    var gender: String?
    var nik: String?

    // Travel / booking
    var bookingCode: String?
    var pnr: String?
    var ticketNumber: String?
    var orderNumber: String?
    var date: String?
    var time: String?           // departure/arrival time — HH:mm only
    var documentTitle: String?
    var origin: String?
    var destination: String?
    var flightNumber: String?
    var seatNumber: String?     // cleaned to e.g. "12A"

    // Hotel / reservation
    var hotelName: String?
    var reservationNumber: String?
    // check-in / check-out removed — was causing incorrect matches

    var extractedFields: [(label: String, value: String)] {
        var fields: [(String, String)] = []
        if let v = documentTitle    { fields.append(("DOCUMENT",        v)) }
        if let v = fullName         { fields.append(("FULL NAME",       v)) }
        if let v = nik              { fields.append(("NIK",             v)) }
        if let v = documentNumber   { fields.append(("DOCUMENT NO.",    v)) }
        if let v = dateOfBirth      { fields.append(("DATE OF BIRTH",   v)) }
        if let v = expiryDate       { fields.append(("EXPIRY DATE",     v)) }
        if let v = nationality      { fields.append(("NATIONALITY",     v)) }
        if let v = gender           { fields.append(("GENDER",          v)) }
        if let v = bookingCode      { fields.append(("BOOKING CODE",    v)) }
        if let v = pnr              { fields.append(("PNR",             v)) }
        if let v = ticketNumber     { fields.append(("TICKET NO.",      v)) }
        if let v = orderNumber      { fields.append(("ORDER NO.",       v)) }
        if let v = flightNumber     { fields.append(("FLIGHT",          v)) }
        if let v = origin           { fields.append(("FROM",            v)) }
        if let v = destination      { fields.append(("TO",              v)) }
        if let v = seatNumber       { fields.append(("SEAT",            v)) }
        if let v = date             { fields.append(("DATE",            v)) }
        if let v = time             { fields.append(("TIME",            v)) }
        if let v = hotelName        { fields.append(("HOTEL",           v)) }
        if let v = reservationNumber { fields.append(("RESERVATION",   v)) }
        return fields
    }
}

// MARK: - OCR Service

final class VisionOCRService {

    static let shared = VisionOCRService()
    private init() {}

    func recognise(image: UIImage, completion: @escaping (ExtractedDocumentData) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ExtractedDocumentData())
            return
        }

        let request = VNRecognizeTextRequest { request, _ in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let raw = lines.joined(separator: "\n")
            var parsed = self.parse(lines: lines, raw: raw)

            let category = DocumentClassifier.shared.classify(data: parsed)
            if category == .boardingPass {
                parsed.isBoardingPass = true
            }

            DispatchQueue.main.async { completion(parsed) }
        }
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        DispatchQueue.global(qos: .userInitiated).async {
            try? VNImageRequestHandler(cgImage: cgImage, options: [:])
                .perform([request])
        }
    }

    // MARK: - Parsing

    private func parse(lines: [String], raw: String) -> ExtractedDocumentData {
        var d = ExtractedDocumentData()
        d.rawText = raw

        for (i, line) in lines.enumerated() {
            let up    = line.uppercased().trimmingCharacters(in: .whitespaces)
            let next  = i + 1 < lines.count ? lines[i + 1].trimmingCharacters(in: .whitespaces) : ""
            let next2 = i + 2 < lines.count ? lines[i + 2].trimmingCharacters(in: .whitespaces) : ""

            // ── Name ──────────────────────────────────────────────────────
            if up.hasPrefix("NAME") || up.hasPrefix("NAMA") || up == "FULL NAME" {
                if !next.isEmpty && !next.isLabelLike { d.fullName = next }
            }

            // ── NIK ───────────────────────────────────────────────────────
            if up == "NIK" || up == "NO. KTP" {
                if next.isNIK { d.nik = next }
            }
            if up.isNIK && d.nik == nil { d.nik = line }

            // ── Document number ───────────────────────────────────────────
            if up.hasPrefix("NO. ") || up.hasPrefix("PASSPORT NO") ||
               up.hasPrefix("DOCUMENT NO") || up.hasPrefix("TICKET NO") ||
               up == "NO. TIKET" {
                if !next.isEmpty { d.documentNumber = next }
            }

            // ── Ticket number ─────────────────────────────────────────────
            if up.hasPrefix("TICKET NO") || up.hasPrefix("NO. TIKET") {
                let candidate = next.isEmpty ? next2 : next
                if !candidate.isEmpty { d.ticketNumber = candidate }
            }

            // ── Booking / PNR ─────────────────────────────────────────────
            if up.contains("BOOKING CODE") || up.contains("BOOKING REF") {
                if !next.isEmpty { d.bookingCode = next }
            }
            if up == "PNR" || up.contains("PNR:") {
                let val = up.hasPrefix("PNR:") ?
                    String(up.dropFirst(4)).trimmingCharacters(in: .whitespaces) : next
                if !val.isEmpty { d.pnr = val }
            }
            if up.looksLikeBookingCode && d.bookingCode == nil { d.bookingCode = line }

            // ── Order number ──────────────────────────────────────────────
            if up.contains("ORDER NO") || up.contains("NO. PESANAN") {
                if !next.isEmpty { d.orderNumber = next }
            }
            if up.looksLikeOrderNumber && d.orderNumber == nil { d.orderNumber = line }

            // ── Dates ─────────────────────────────────────────────────────
            if up.contains("DATE OF BIRTH") || up.contains("DOB") || up.contains("TGL LAHIR") {
                if !next.isEmpty { d.dateOfBirth = next }
            }
            if up.contains("EXPIRY") || up.contains("BERLAKU HINGGA") || up.contains("VALID UNTIL") {
                if !next.isEmpty { d.expiryDate = next }
            }
            if (up.contains("VALID FOR") || up.contains("BERLAKU PADA")) && !next.isEmpty {
                d.date = next
            }
            // Capture standalone date lines
            if line.looksLikeDate && d.date == nil { d.date = line.extractedDate }

            // ── Time — extract HH:mm only ─────────────────────────────────
            if line.looksLikeTime && d.time == nil {
                d.time = line.extractedTime
            }

            // ── Nationality ───────────────────────────────────────────────
            if up == "NATIONALITY" || up == "KEWARGANEGARAAN" {
                if !next.isEmpty { d.nationality = next }
            }

            // ── Gender ────────────────────────────────────────────────────
            if up == "GENDER" || up == "SEX" || up == "JENIS KELAMIN" {
                if !next.isEmpty { d.gender = next }
            }

            // ── Flight ────────────────────────────────────────────────────
            if up.hasPrefix("FLIGHT") { d.flightNumber = next.isEmpty ? nil : next }
            if up.looksLikeFlightNumber && d.flightNumber == nil { d.flightNumber = line }

            // ── Seat — strip to alphanumeric only (e.g. "12A") ───────────
            if up.hasPrefix("SEAT") {
                let raw = next.isEmpty ? next2 : next
                d.seatNumber = raw.cleanedSeat
            }
            // Inline "SEAT: 12A" or just "12A" pattern mid-line
            if d.seatNumber == nil, let inline = up.inlineSeat {
                d.seatNumber = inline
            }

            // ── Origin / Destination ──────────────────────────────────────
            if up.hasPrefix("FROM") || up.hasPrefix("ORIGIN") || up.hasPrefix("ASAL") {
                if !next.isEmpty && !next.isLabelLike { d.origin = next }
            }
            if up.hasPrefix("TO") || up.hasPrefix("DESTINATION") || up.hasPrefix("TUJUAN") {
                if !next.isEmpty && !next.isLabelLike { d.destination = next }
            }

            // ── Hotel ─────────────────────────────────────────────────────
            if up.contains("HOTEL") && !next.isEmpty { d.hotelName = next }

            // ── Reservation ───────────────────────────────────────────────
            if up.contains("RESERVATION") || up.contains("BOOKING ID") {
                if !next.isEmpty { d.reservationNumber = next }
            }

            // ── Document title (first non-label line near top) ────────────
            if d.documentTitle == nil &&
               line.count > 6 && !up.isLabelLike &&
               !up.isNIK && !line.looksLikeDate &&
               i < 6 {
                d.documentTitle = line
            }
        }

        return d
    }
}

// MARK: - String helpers

private extension String {

    var isLabelLike: Bool {
        let keywords = ["NAME","NAMA","NIK","NO.","DATE","EXPIRY","VALID","NATIONALITY",
                        "GENDER","SEX","DOB","BOOKING","PNR","ORDER","FLIGHT","SEAT",
                        "HOTEL","RESERVATION","TICKET","PRICE","HARGA","BERLAKU",
                        "FROM","TO","ORIGIN","DESTINATION","TIME"]
        let up = uppercased()
        return keywords.contains(where: { up.contains($0) })
    }

    var isNIK: Bool {
        let digits = filter(\.isNumber)
        return digits.count == 16 && count <= 17
    }

    var looksLikeBookingCode: Bool {
        guard count >= 6 && count <= 22 && !contains(" ") else { return false }
        return uppercased().allSatisfy({ $0.isLetter || $0.isNumber })
    }

    var looksLikeOrderNumber: Bool {
        range(of: #"^[A-Z]\d{5}-\d{6}[A-Z]-\d{3}$"#, options: .regularExpression) != nil
    }

    var looksLikeDate: Bool {
        let patterns = [
            #"\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}"#,
            #"\d{1,2}\s+\w+\s+\d{4}"#,
            #"\w+\s+\d{1,2},?\s+\d{4}"#,
            #"\d{2}\s+\w{3}\s+\d{4}"#,
        ]
        return patterns.contains { range(of: $0, options: .regularExpression) != nil }
    }

    /// Extracts and normalises date portion only
    var extractedDate: String {
        let patterns = [
            #"\d{1,2}[\/\-]\d{1,2}[\/\-]\d{2,4}"#,
            #"\d{2}\s+\w{3}\s+\d{4}"#,
            #"\d{1,2}\s+\w+\s+\d{4}"#,
            #"\w+\s+\d{1,2},?\s+\d{4}"#,
        ]
        for p in patterns {
            if let r = range(of: p, options: .regularExpression) {
                return String(self[r])
            }
        }
        return self
    }

    /// True if line contains a time like 08:35 or 08.35
    var looksLikeTime: Bool {
        range(of: #"\b([01]?\d|2[0-3])[:\.]([0-5]\d)\b"#, options: .regularExpression) != nil
    }

    /// Extracts "HH:mm" from a line that may contain other text
    var extractedTime: String? {
        guard let r = range(of: #"\b([01]?\d|2[0-3])[:\.]([0-5]\d)\b"#,
                            options: .regularExpression) else { return nil }
        return String(self[r]).replacingOccurrences(of: ".", with: ":")
    }

    var looksLikeFlightNumber: Bool {
        range(of: #"^[A-Z]{2}\d{3,4}$"#, options: .regularExpression) != nil
    }

    /// Strips everything except letters and digits, keeps only seat-like value (e.g. "12A")
    var cleanedSeat: String? {
        // Remove common noise words
        let noise = ["SEAT", "KURSI", "NO", "NUMBER", ":", "-", " "]
        var s = uppercased()
        for n in noise { s = s.replacingOccurrences(of: n, with: "") }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        // Must be 2–4 chars, letters+digits only, looks like a seat code
        guard s.count >= 2 && s.count <= 5,
              s.allSatisfy({ $0.isLetter || $0.isNumber }),
              s.contains(where: { $0.isNumber })
        else { return nil }
        return s
    }

    /// Detects inline "SEAT 12A" or "SEAT: 12A" on the same line
    var inlineSeat: String? {
        guard let r = range(of: #"(?:SEAT|KURSI)[:\s]+([A-Z0-9]{2,5})"#,
                            options: [.regularExpression, .caseInsensitive]) else { return nil }
        let match = String(self[r])
        // Extract just the seat code after the label
        if let codeRange = match.range(of: #"[A-Z0-9]{2,5}$"#, options: .regularExpression) {
            return String(match[codeRange])
        }
        return nil
    }
}
