//
//  DocumentTextClassifier.swift
//  hh
//
//  On-device text classifier trained with Create ML
//  (MLTextClassifier, transfer learning on BERT embeddings).
//
//  Drop the trained `DocumentTypeClassifier.mlmodel` into the `hh/` folder —
//  Xcode compiles it to `DocumentTypeClassifier.mlmodelc` in the app bundle.
//  Until then `predict` returns nil and the rule-based classifier is used.
//  See Tools/DocumentClassifierTraining/README.md.
//

import Foundation
import CoreML
import NaturalLanguage

final class DocumentTextClassifier {

    static let shared = DocumentTextClassifier()
    static let modelName = "DocumentTypeClassifier"

    private let model: NLModel?

    var isAvailable: Bool { model != nil }

    private init() {
        guard let url = Bundle.main.url(forResource: Self.modelName, withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: url),
              let nlModel = try? NLModel(mlModel: mlModel)
        else {
            model = nil
            return
        }
        model = nlModel
    }

    /// Best category and its probability, or nil when no model is bundled
    /// or the text is empty.
    func predict(_ rawText: String) -> (category: DocumentCategory, confidence: Double)? {
        guard let model else { return nil }
        let text = Self.normalise(rawText)
        guard !text.isEmpty else { return nil }

        let hypotheses = model.predictedLabelHypotheses(for: text, maximumCount: 3)
        guard let best = hypotheses.max(by: { $0.value < $1.value }),
              let category = DocumentCategory(trainingLabel: best.key)
        else { return nil }
        return (category, best.value)
    }

    /// Text normalisation shared by training-data export and inference.
    /// Must stay identical on both sides — retrain the model if you change it.
    ///  • lowercased, whitespace collapsed to single spaces
    ///  • digit runs replaced with "0" (numbers vary per document and are noise)
    ///  • MRZ filler "<" removed
    ///  • capped at 2000 characters
    static func normalise(_ raw: String) -> String {
        var s = raw.lowercased().replacingOccurrences(of: "<", with: " ")
        s = s.replacingOccurrences(of: #"\d+"#, with: "0", options: .regularExpression)
        s = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return String(s.prefix(2000))
    }
}
