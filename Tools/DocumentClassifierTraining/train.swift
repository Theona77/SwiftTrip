#!/usr/bin/env swift
//
//  train.swift
//  Trains DocumentTypeClassifier.mlmodel — a Create ML text classifier using
//  transfer learning on Apple's BERT embeddings (multilingual, so Indonesian
//  and English text both work). Runs on macOS 14+ with Xcode installed.
//
//  Usage:
//    swift train.swift <data.json> [more.json ...] [--out DocumentTypeClassifier.mlmodel]
//                      [--maxent]
//
//  Each JSON file is an array of objects with at least "text" and "label":
//    [{ "text": "republik indonesia provinsi ...", "label": "nationalID" }, ...]
//  `samples.json` exported by the app (TrainingSampleRecorder) already has
//  this shape and is normalised. Hand-written data must be normalised the same
//  way as DocumentTextClassifier.normalise — this script re-applies it, so raw
//  OCR text is fine too.
//
//  Labels must be DocumentCategory.trainingLabel values:
//    nationalID passport visa boardingPass hotel train reservation activity event other
//

import CreateML
import Foundation
import NaturalLanguage

let validLabels: Set<String> = ["nationalID", "passport", "visa", "boardingPass", "hotel",
                                "train", "reservation", "activity", "event", "other"]

// MARK: - Arguments

var inputs: [URL] = []
var output = URL(fileURLWithPath: "DocumentTypeClassifier.mlmodel")
var useMaxEnt = false

var args = CommandLine.arguments.dropFirst().makeIterator()
while let arg = args.next() {
    switch arg {
    case "--out":    if let path = args.next() { output = URL(fileURLWithPath: path) }
    case "--maxent": useMaxEnt = true
    default:         inputs.append(URL(fileURLWithPath: arg))
    }
}
guard !inputs.isEmpty else {
    print("usage: swift train.swift <data.json> [more.json ...] [--out path.mlmodel] [--maxent]")
    exit(1)
}

// MARK: - Normalisation (keep identical to DocumentTextClassifier.normalise)

func normalise(_ raw: String) -> String {
    var s = raw.lowercased().replacingOccurrences(of: "<", with: " ")
    s = s.replacingOccurrences(of: #"\d+"#, with: "0", options: .regularExpression)
    s = s.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    return String(s.prefix(2000))
}

// MARK: - Load data

struct Row: Decodable { let text: String; let label: String }

var texts: [String] = []
var labels: [String] = []
for url in inputs {
    let rows = try JSONDecoder().decode([Row].self, from: Data(contentsOf: url))
    for row in rows {
        guard validLabels.contains(row.label) else {
            print("⚠️  skipping unknown label \"\(row.label)\" in \(url.lastPathComponent)")
            continue
        }
        let text = normalise(row.text)
        guard !text.isEmpty else { continue }
        texts.append(text)
        labels.append(row.label)
    }
}

let counts = Dictionary(grouping: labels, by: { $0 }).mapValues(\.count)
print("Loaded \(texts.count) samples:")
for label in validLabels.sorted() {
    let n = counts[label, default: 0]
    print("  \(label.padding(toLength: 13, withPad: " ", startingAt: 0)) \(n)\(n < 20 ? "  ← needs more data" : "")")
}

let table = try MLDataTable(dictionary: ["text": texts, "label": labels])
let (trainData, testData) = table.randomSplit(by: 0.8, seed: 42)

// MARK: - Train

let algorithm: MLTextClassifier.ModelAlgorithmType = useMaxEnt
    ? .maxEnt(revision: 1)
    : .transferLearning(.bertEmbedding, revision: 1)

let parameters = MLTextClassifier.ModelParameters(
    validation: .split(strategy: .automatic),
    algorithm: algorithm,
    language: nil          // BERT embeddings are multilingual
)

print("\nTraining (\(useMaxEnt ? "MaxEnt" : "BERT transfer learning"))…")
let classifier = try MLTextClassifier(trainingData: trainData,
                                      textColumn: "text",
                                      labelColumn: "label",
                                      parameters: parameters)

// MARK: - Evaluate

let trainAcc = (1 - classifier.trainingMetrics.classificationError) * 100
let validAcc = (1 - classifier.validationMetrics.classificationError) * 100
let evaluation = classifier.evaluation(on: testData, textColumn: "text", labelColumn: "label")
let testAcc = (1 - evaluation.classificationError) * 100

print(String(format: "\nAccuracy  train %.1f%%   validation %.1f%%   test %.1f%%",
             trainAcc, validAcc, testAcc))
print("\nPer-class precision / recall (test):")
print(evaluation.precisionRecall)
print("\nConfusion matrix (test):")
print(evaluation.confusion)

// MARK: - Save

let metadata = MLModelMetadata(
    author: "SwiftTrip",
    shortDescription: "Classifies OCR text of travel documents into DocumentCategory labels.",
    version: "1.0"
)
try classifier.write(to: output, metadata: metadata)
print("\nSaved \(output.path)")
print("Drag it into the hh/ folder in Xcode — it must be named DocumentTypeClassifier.mlmodel.")
