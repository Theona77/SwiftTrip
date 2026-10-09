//
//  MRZParser.swift
//  hh
//
//  Parses the Machine Readable Zone (ICAO 9303) printed on passports,
//  visas and some ID cards. Supports TD1 (3×30), TD2 / MRV-B (2×36)
//  and TD3 / MRV-A (2×44). Every field carries a check digit, so a
//  valid MRZ is the most reliable signal we get from OCR.
//

import Foundation

// MARK: - Result

struct MRZResult: Equatable {
    enum Kind: Equatable { case passport, visa, idCard }

    var kind: Kind
    var documentCode: String
    var issuingCountry: String
    var surname: String
    var givenNames: String
    var documentNumber: String
    var nationality: String
    var dateOfBirth: String?    // "dd MMM yyyy"
    var expiryDate: String?     // "dd MMM yyyy"
    var sex: String?            // "M", "F" or nil

    var documentNumberValid: Bool
    var dateOfBirthValid: Bool
    var expiryDateValid: Bool

    var fullName: String {
        [givenNames, surname].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// True when the core check digits all match — the MRZ was read correctly.
    var isValid: Bool { documentNumberValid && dateOfBirthValid && expiryDateValid }
}

// MARK: - Parser

enum MRZParser {

    /// Scans OCR lines for an MRZ block and parses it.
    static func parse(lines: [String]) -> MRZResult? {
        let candidates = lines.map(normalise).filter(isCandidate)
        guard candidates.count >= 2 else { return nil }

        // Try consecutive 3-line blocks (TD1), then 2-line blocks (TD2/TD3).
        if candidates.count >= 3 {
            for i in 0...(candidates.count - 3) {
                if let r = parseTD1(candidates[i], candidates[i + 1], candidates[i + 2]) { return r }
            }
        }
        for i in 0...(candidates.count - 2) {
            if let r = parseTwoLine(candidates[i], candidates[i + 1]) { return r }
        }
        return nil
    }

    // MARK: Line clean-up

    static func normalise(_ line: String) -> String {
        var s = line.uppercased()
        for (from, to) in [("«", "<<"), ("‹", "<"), ("‘", "<"), ("(", "<"), ("[", "<"), ("{", "<")] {
            s = s.replacingOccurrences(of: from, with: to)
        }
        return String(s.filter { !$0.isWhitespace })
    }

    private static func isCandidate(_ s: String) -> Bool {
        guard s.count >= 28, s.contains("<") else { return false }
        let valid = s.filter { $0 == "<" || ("A"..."Z").contains($0) || $0.isASCIIDigit }
        return Double(valid.count) / Double(s.count) >= 0.9
    }

    /// Strips noise, then pads with fillers / truncates to the exact length.
    /// Only lines within ±2 characters of `length` are accepted.
    private static func fit(_ s: String, to length: Int) -> [Character]? {
        let clean = s.filter { $0 == "<" || ("A"..."Z").contains($0) || $0.isASCIIDigit }
        guard abs(clean.count - length) <= 2 else { return nil }
        var chars = Array(clean.prefix(length))
        while chars.count < length { chars.append("<") }
        return chars
    }

    // MARK: Formats

    /// TD3 passport (2×44), MRV-A visa (2×44), TD2 (2×36), MRV-B visa (2×36).
    private static func parseTwoLine(_ l1: String, _ l2: String) -> MRZResult? {
        for length in [44, 36] {
            guard let a = fit(l1, to: length), let b = fit(l2, to: length) else { continue }
            guard let kind = kind(for: a[0]) else { continue }

            let (surname, given) = names(from: a[5..<length])
            let docNum  = alnumField(b[0..<9])
            let dob     = numericField(b[13..<19])
            let expiry  = numericField(b[21..<27])

            let result = MRZResult(
                kind: kind,
                documentCode: String(a[0..<2]).replacingOccurrences(of: "<", with: ""),
                issuingCountry: countryField(a[2..<5]),
                surname: surname,
                givenNames: given,
                documentNumber: docNum.replacingOccurrences(of: "<", with: ""),
                nationality: countryField(b[10..<13]),
                dateOfBirth: formatDate(dob, isExpiry: false),
                expiryDate: formatDate(expiry, isExpiry: true),
                sex: sex(b[20]),
                documentNumberValid: checkDigit(docNum, b[9]),
                dateOfBirthValid: checkDigit(dob, b[19]),
                expiryDateValid: checkDigit(expiry, b[27])
            )
            // Reject look-alike text where no check digit matches.
            if result.documentNumberValid || result.dateOfBirthValid || result.expiryDateValid {
                return result
            }
        }
        return nil
    }

    /// TD1 ID card (3×30).
    private static func parseTD1(_ l1: String, _ l2: String, _ l3: String) -> MRZResult? {
        guard let a = fit(l1, to: 30), let b = fit(l2, to: 30), let c = fit(l3, to: 30),
              let kind = kind(for: a[0]) else { return nil }

        let docNum = alnumField(a[5..<14])
        let dob    = numericField(b[0..<6])
        let expiry = numericField(b[8..<14])
        let (surname, given) = names(from: c[0..<30])

        let result = MRZResult(
            kind: kind,
            documentCode: String(a[0..<2]).replacingOccurrences(of: "<", with: ""),
            issuingCountry: countryField(a[2..<5]),
            surname: surname,
            givenNames: given,
            documentNumber: docNum.replacingOccurrences(of: "<", with: ""),
            nationality: countryField(b[15..<18]),
            dateOfBirth: formatDate(dob, isExpiry: false),
            expiryDate: formatDate(expiry, isExpiry: true),
            sex: sex(b[7]),
            documentNumberValid: checkDigit(docNum, a[14]),
            dateOfBirthValid: checkDigit(dob, b[6]),
            expiryDateValid: checkDigit(expiry, b[14])
        )
        // A 3-line block that fails every check is almost certainly not TD1.
        return (result.dateOfBirthValid || result.expiryDateValid) ? result : nil
    }

    // MARK: Field helpers

    private static func kind(for code: Character) -> MRZResult.Kind? {
        switch code {
        case "P":           return .passport
        case "V":           return .visa
        case "I", "A", "C": return .idCard
        default:            return nil
        }
    }

    private static func names(from chars: ArraySlice<Character>) -> (String, String) {
        let raw = String(chars)
        let parts = raw.components(separatedBy: "<<")
        let surname = clean(parts.first ?? "")
        let given = clean(parts.dropFirst().joined(separator: " "))
        return (surname, given)
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "<", with: " ")
            .map { $0.isASCIIDigit ? letterLookalike($0) : $0 }
            .reduce(into: "") { $0.append($1) }
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func countryField(_ chars: ArraySlice<Character>) -> String {
        String(chars.map { $0.isASCIIDigit ? letterLookalike($0) : $0 })
            .replacingOccurrences(of: "<", with: "")
    }

    /// Numeric fields (dates, check digits) — fix letters OCR'd in place of digits.
    private static func numericField(_ chars: ArraySlice<Character>) -> String {
        String(chars.map(digitLookalike))
    }

    private static func alnumField(_ chars: ArraySlice<Character>) -> String {
        String(chars)
    }

    private static func sex(_ c: Character) -> String? {
        c == "M" || c == "F" ? String(c) : nil
    }

    private static func digitLookalike(_ c: Character) -> Character {
        switch c {
        case "O", "Q", "D": return "0"
        case "I", "L":      return "1"
        case "Z":           return "2"
        case "S":           return "5"
        case "G":           return "6"
        case "B":           return "8"
        default:            return c
        }
    }

    private static func letterLookalike(_ c: Character) -> Character {
        switch c {
        case "0": return "O"
        case "1": return "I"
        case "2": return "Z"
        case "5": return "S"
        case "8": return "B"
        default:  return c
        }
    }

    // MARK: Check digits (ICAO 9303: weights 7-3-1)

    static func checkDigit(_ field: String, _ expected: Character) -> Bool {
        guard let expectedValue = digitLookalike(expected).wholeNumberValue else { return false }
        return computeCheckDigit(field) == expectedValue
    }

    static func computeCheckDigit(_ field: String) -> Int {
        let weights = [7, 3, 1]
        var sum = 0
        for (i, c) in field.enumerated() {
            let value: Int
            if let d = c.wholeNumberValue, c.isASCIIDigit {
                value = d
            } else if let ascii = c.asciiValue, c >= "A" && c <= "Z" {
                value = Int(ascii) - 55        // A = 10 … Z = 35
            } else {
                value = 0                      // "<" filler
            }
            sum += value * weights[i % 3]
        }
        return sum % 10
    }

    // MARK: Dates (YYMMDD)

    private static func formatDate(_ yymmdd: String, isExpiry: Bool) -> String? {
        let digits = yymmdd.compactMap(\.wholeNumberValue)
        guard digits.count == 6 else { return nil }
        let yy = digits[0] * 10 + digits[1]
        let mm = digits[2] * 10 + digits[3]
        let dd = digits[4] * 10 + digits[5]
        guard (1...12).contains(mm), (1...31).contains(dd) else { return nil }

        let currentYY = Calendar(identifier: .gregorian).component(.year, from: Date()) % 100
        // Expiry dates are in this century; birth dates later than this year are last century.
        let year = isExpiry ? 2000 + yy : (yy > currentYY ? 1900 + yy : 2000 + yy)

        let months = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
        return String(format: "%02d %@ %04d", dd, months[mm - 1], year)
    }
}

private extension Character {
    var isASCIIDigit: Bool { ("0"..."9").contains(self) }
}
