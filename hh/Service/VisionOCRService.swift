//
//  VisionOCRService.swift
//  hh
//

import Vision
import UIKit
import ImageIO

// MARK: - Extracted Document Data

struct ExtractedDocumentData {
    var rawText: String = ""
    var isBoardingPass: Bool = false
    var mrz: MRZResult?

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

    /// Languages we try to read, in priority order. Filtered at runtime
    /// against what the current OS supports.
    private let preferredLanguages = ["id-ID", "en-US"]

    func recognise(image: UIImage, completion: @escaping (ExtractedDocumentData) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(ExtractedDocumentData())
            return
        }
        let orientation = CGImagePropertyOrientation(image.imageOrientation)

        let request = VNRecognizeTextRequest { request, _ in
            let observations = request.results as? [VNRecognizedTextObservation] ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            let raw = lines.joined(separator: "\n")
            let parsed = self.parse(lines: lines, raw: raw)
            DispatchQueue.main.async { completion(parsed) }
        }
        request.recognitionLevel = .accurate
        // Language correction "fixes" codes (PNR, passport no., NIK, MRZ) into
        // dictionary words — e.g. 0→O, 1→I — so keep it off.
        request.usesLanguageCorrection = false
        if let supported = try? request.supportedRecognitionLanguages() {
            let languages = preferredLanguages.filter { supported.contains($0) }
            if !languages.isEmpty { request.recognitionLanguages = languages }
        }

        DispatchQueue.global(qos: .userInitiated).async {
            // Pass the EXIF orientation, otherwise rotated photos are read sideways.
            try? VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                .perform([request])
        }
    }

    // MARK: - Parsing

    func parse(lines: [String], raw: String) -> ExtractedDocumentData {
        var d = ExtractedDocumentData()
        d.rawText = raw

        for (i, line) in lines.enumerated() {
            let up    = line.uppercased().trimmingCharacters(in: .whitespaces)
            let next  = i + 1 < lines.count ? lines[i + 1].trimmingCharacters(in: .whitespaces) : ""
            let next2 = i + 2 < lines.count ? lines[i + 2].trimmingCharacters(in: .whitespaces) : ""

            /// Value for a labelled field, or nil if this line isn't one of `labels`.
            /// Uses the same line ("Flight GA 410", "Name: Budi") when it has a value,
            /// otherwise the next line.
            func value(for labels: [String], skippingLabels: Bool = true) -> String? {
                guard let rest = line.remainder(afterLabel: labels) else { return nil }
                if !rest.isEmpty {
                    if !rest.isLabelLike { return rest }
                    // Bilingual label, e.g. "Nama Lengkap/Full Name: Budi"
                    if let inline = rest.inlineValue { return inline }
                }
                if next.isEmpty || (skippingLabels && next.isLabelLike) { return nil }
                return next
            }

            // ── Name ──────────────────────────────────────────────────────
            // "Nama Hotel", "Nama Ibu" … are other fields, not the holder's name.
            if d.fullName == nil,
               !up.containsWord(["HOTEL", "PROPERTY", "IBU", "AYAH", "FILE"]),
               let v = value(for: ["NAME", "NAMA", "FULL NAME", "NAMA LENGKAP",
                                   "PASSENGER NAME", "GUEST NAME"]) {
                d.fullName = v
            }

            // ── NIK ───────────────────────────────────────────────────────
            if let v = value(for: ["NIK", "NO. KTP"]), v.isNIK { d.nik = v.filter(\.isNumber) }
            if up.isNIK && d.nik == nil { d.nik = line.filter(\.isNumber) }

            // ── Document number ───────────────────────────────────────────
            if let v = value(for: ["PASSPORT NO", "PASSPORT NO.", "PASSPORT NUMBER", "NO. PASPOR",
                                   "DOCUMENT NO", "DOCUMENT NO.", "DOCUMENT NUMBER", "NO. DOKUMEN"]) {
                d.documentNumber = v
            }

            // ── Ticket number ─────────────────────────────────────────────
            if let rest = line.remainder(afterLabel: ["TICKET NO", "TICKET NO.", "TICKET NUMBER", "NO. TIKET"]) {
                let candidate = !rest.isEmpty ? rest : (next.isEmpty ? next2 : next)
                if !candidate.isEmpty { d.ticketNumber = candidate }
            }

            // ── Booking / PNR ─────────────────────────────────────────────
            if let v = value(for: ["BOOKING CODE", "BOOKING REF", "BOOKING REFERENCE",
                                   "KODE BOOKING", "KODE PEMESANAN"]) {
                d.bookingCode = v
            }
            if let v = value(for: ["PNR"]) { d.pnr = v }
            if up.looksLikeBookingCode && d.bookingCode == nil { d.bookingCode = line }

            // ── Order number ──────────────────────────────────────────────
            if let v = value(for: ["ORDER NO", "ORDER NO.", "ORDER NUMBER", "ORDER ID", "NO. PESANAN"]) {
                d.orderNumber = v
            }
            if up.looksLikeOrderNumber && d.orderNumber == nil { d.orderNumber = line }

            // ── Dates ─────────────────────────────────────────────────────
            // Labels like "Tempat/Tgl Lahir" or "Tgl. Lahir/Date of birth" vary a lot,
            // so match on contains and take the date from this line or the next.
            if up.contains("DATE OF BIRTH") || up.startsWithLabel(["DOB"]) || up.contains("TGL LAHIR") ||
               up.contains("TGL. LAHIR") {
                let source = line.looksLikeDate ? line : next
                if source.looksLikeDate { d.dateOfBirth = source.extractedDate }
            }
            if up.contains("EXPIRY") || up.contains("EXPIRATION") ||
               up.contains("BERLAKU HINGGA") || up.contains("VALID UNTIL") {
                let source = line.looksLikeDate ? line : next
                if source.looksLikeDate {
                    d.expiryDate = source.extractedDate
                } else if let inline = line.inlineValue {
                    d.expiryDate = inline                       // e.g. "SEUMUR HIDUP"
                } else if !next.isEmpty && !next.isLabelLike {
                    d.expiryDate = next
                }
            }
            if up.contains("VALID FOR") || up.contains("BERLAKU PADA") {
                let source = line.looksLikeDate ? line : next
                if source.looksLikeDate { d.date = source.extractedDate }
            }
            // Capture standalone date lines
            if line.looksLikeDate && d.date == nil { d.date = line.extractedDate }

            // ── Time — extract HH:mm only ─────────────────────────────────
            if line.looksLikeTime && d.time == nil {
                d.time = line.extractedTime
            }

            // ── Nationality ───────────────────────────────────────────────
            if let v = value(for: ["NATIONALITY", "KEWARGANEGARAAN"]) { d.nationality = v }

            // ── Gender ────────────────────────────────────────────────────
            if let v = value(for: ["GENDER", "SEX", "JENIS KELAMIN"]) { d.gender = v }

            // ── Flight ────────────────────────────────────────────────────
            if let v = value(for: ["FLIGHT", "FLIGHT NO", "FLIGHT NO.", "FLIGHT NUMBER", "PENERBANGAN"]),
               v.uppercased().containsFlightNumber {
                d.flightNumber = v
            }
            if up.looksLikeFlightNumber && d.flightNumber == nil { d.flightNumber = line }

            // ── Seat — strip to alphanumeric only (e.g. "12A") ───────────
            if let rest = line.remainder(afterLabel: ["SEAT", "SEAT NO", "KURSI", "NO. KURSI"]) {
                let raw = !rest.isEmpty ? rest : (next.isEmpty ? next2 : next)
                if let seat = raw.cleanedSeat { d.seatNumber = seat }
            }
            // Inline "... SEAT: 12A" pattern mid-line
            if d.seatNumber == nil, let inline = up.inlineSeat {
                d.seatNumber = inline
            }

            // ── Origin / Destination ──────────────────────────────────────
            if let v = value(for: ["FROM", "ORIGIN", "ASAL", "DEPARTURE CITY"]), !v.looksLikeDate {
                d.origin = v
            }
            if let v = value(for: ["TO", "DESTINATION", "TUJUAN", "ARRIVAL CITY"]), !v.looksLikeDate {
                d.destination = v
            }

            // ── Hotel ─────────────────────────────────────────────────────
            // A labelled hotel field ("Hotel name", "Nama Hotel", bare "Hotel", "Hotel: X").
            // A line like "Hotel Indonesia Kempinski" is the name itself — handled below.
            let isHotelLabel = up == "HOTEL" ||
                up.range(of: #"^HOTEL\s*:"#, options: .regularExpression) != nil ||
                line.remainder(afterLabel: ["HOTEL NAME", "NAMA HOTEL", "PROPERTY NAME"]) != nil
            if isHotelLabel,
               let v = value(for: ["HOTEL", "HOTEL NAME", "NAMA HOTEL", "PROPERTY NAME"]) {
                d.hotelName = v
            } else if d.hotelName == nil, line.count <= 60,
                      up.containsWord(["HOTEL", "RESORT", "HOSTEL", "VILLA", "VILLAS"]),
                      !up.containsWord(["CHECK", "CHECK-IN", "CHECK-OUT", "VOUCHER", "CONFIRMATION"]) {
                d.hotelName = line.trimmingCharacters(in: .whitespaces)
            }

            // ── Reservation ───────────────────────────────────────────────
            if let v = value(for: ["RESERVATION NO", "RESERVATION NUMBER", "RESERVATION CODE",
                                   "RESERVATION ID", "CONFIRMATION NO", "CONFIRMATION NUMBER",
                                   "CONFIRMATION CODE", "BOOKING ID", "BOOKING NO",
                                   "BOOKING NUMBER", "NO. RESERVASI"]) {
                d.reservationNumber = v
            }

            // ── Document title (first non-label line near top) ────────────
            if d.documentTitle == nil &&
               line.count > 6 && !up.isLabelLike &&
               !up.isNIK && !line.looksLikeDate &&
               i < 6 {
                d.documentTitle = line
            }
        }

        applyMRZ(MRZParser.parse(lines: lines), to: &d)
        return d
    }

    /// MRZ fields are check-digit verified, so they override label-parsed values.
    private func applyMRZ(_ mrz: MRZResult?, to d: inout ExtractedDocumentData) {
        guard let mrz else { return }
        d.mrz = mrz

        if !mrz.fullName.isEmpty                        { d.fullName = mrz.fullName }
        if mrz.documentNumberValid || d.documentNumber == nil {
            d.documentNumber = mrz.documentNumber
        }
        if let dob = mrz.dateOfBirth, mrz.dateOfBirthValid || d.dateOfBirth == nil {
            d.dateOfBirth = dob
        }
        if let exp = mrz.expiryDate, mrz.expiryDateValid || d.expiryDate == nil {
            d.expiryDate = exp
        }
        if !mrz.nationality.isEmpty                     { d.nationality = mrz.nationality }
        if let sex = mrz.sex                            { d.gender = sex }

        // MRZ lines are not booking codes / titles.
        if let code = d.bookingCode, code.contains("<") { d.bookingCode = nil }
    }
}

// MARK: - Orientation

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up:            self = .up
        case .upMirrored:    self = .upMirrored
        case .down:          self = .down
        case .downMirrored:  self = .downMirrored
        case .left:          self = .left
        case .leftMirrored:  self = .leftMirrored
        case .right:         self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
    }
}

// MARK: - String helpers

extension String {

    /// True if the line starts with one of `labels` followed by a non-letter
    /// (end, ":", space, "/" …). "TO" matches "TO: BALI" but not "TOTAL".
    func startsWithLabel(_ labels: [String]) -> Bool {
        let up = uppercased().trimmingCharacters(in: .whitespaces)
        return labels.contains { label in
            guard up.hasPrefix(label) else { return false }
            guard let nextChar = up.dropFirst(label.count).first else { return true }
            return !(nextChar.isLetter || nextChar.isNumber)
        }
    }

    /// Whole-word match, so "INN" does not match "DINNER".
    func containsWord(_ words: [String]) -> Bool {
        let tokens = Set(uppercased().split(whereSeparator: { !($0.isLetter || $0.isNumber || $0 == "-") })
                            .map(String.init))
        return words.contains { tokens.contains($0) }
    }

    /// If the line starts with one of `labels` (longest match wins), returns
    /// what follows it with separators trimmed — possibly "". Nil otherwise.
    func remainder(afterLabel labels: [String]) -> String? {
        let trimmed = trimmingCharacters(in: .whitespaces)
        guard let label = labels.sorted(by: { $0.count > $1.count })
                .first(where: { trimmed.startsWithLabel([$0]) }) else { return nil }
        return String(trimmed.dropFirst(label.count))
            .trimmingCharacters(in: CharacterSet(charactersIn: " :.-/\t"))
    }

    /// Text after the first ":" when present, e.g. "Name: John Doe" → "John Doe".
    var inlineValue: String? {
        guard let colon = firstIndex(of: ":") else { return nil }
        let v = self[index(after: colon)...].trimmingCharacters(in: .whitespaces)
        // "08:35" is a time, not a label/value pair.
        if let before = self[..<colon].last, before.isNumber, v.first?.isNumber == true { return nil }
        return v.isEmpty ? nil : v
    }
}

private extension String {

    var isLabelLike: Bool {
        // Whole words only, so a name like "ANTON" isn't mistaken for the "TO" label.
        let keywords = ["NAME","NAMA","NIK","NO","DATE","EXPIRY","VALID","NATIONALITY",
                        "GENDER","SEX","DOB","BOOKING","PNR","ORDER","FLIGHT","SEAT",
                        "HOTEL","RESERVATION","TICKET","PRICE","HARGA","BERLAKU",
                        "FROM","TO","ORIGIN","DESTINATION","TIME"]
        return containsWord(keywords)
    }

    var isNIK: Bool {
        let digits = filter(\.isNumber)
        return digits.count == 16 && count <= 17
    }

    /// Standalone code like "XK7QZ2" or "1234ABCD5678". Requires both letters
    /// and digits so ordinary words ("PASSPORT", "INDONESIA") don't match.
    var looksLikeBookingCode: Bool {
        guard count >= 6 && count <= 22 && !contains(" ") else { return false }
        let up = uppercased()
        guard up.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber) }),
              up.contains(where: \.isLetter),
              up.contains(where: \.isNumber),
              !up.isNIK, !up.looksLikeFlightNumber
        else { return false }
        return true
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
        range(of: #"^[A-Z0-9]{2}\s?\d{2,4}$"#, options: .regularExpression) != nil
            && contains(where: \.isLetter)
    }

    var containsFlightNumber: Bool {
        range(of: #"\b[A-Z0-9]{2}\s?\d{2,4}\b"#, options: .regularExpression) != nil
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
