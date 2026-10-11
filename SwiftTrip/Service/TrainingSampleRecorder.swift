//
//  TrainingSampleRecorder.swift
//  hh
//
//  Collects training data for the Create ML document classifier: the OCR
//  text of each saved scan plus the category the user confirmed.
//
//  OCR text from IDs and passports is personal data, so recording is only
//  enabled in DEBUG builds and the file never leaves the device unless you
//  download the app container from Xcode (Window ▸ Devices and Simulators ▸
//  hh ▸ Download Container…). The file is at:
//      Documents/ClassifierTraining/samples.json
//

import Foundation

final class TrainingSampleRecorder {

    static let shared = TrainingSampleRecorder()

    #if DEBUG
    var isEnabled = true
    #else
    var isEnabled = false
    #endif

    struct Sample: Codable {
        let text: String        // DocumentTextClassifier.normalise(rawText)
        let label: String       // DocumentCategory.trainingLabel confirmed by the user
        let predicted: String   // what the classifier said — useful to find mistakes
        let date: Date
    }

    var fileURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClassifierTraining", isDirectory: true)
            .appendingPathComponent("samples.json")
    }

    private init() {}

    func record(text rawText: String, confirmed: DocumentCategory, predicted: DocumentCategory) {
        guard isEnabled else { return }
        let text = DocumentTextClassifier.normalise(rawText)
        guard text.count > 10 else { return }

        let sample = Sample(text: text,
                            label: confirmed.trainingLabel,
                            predicted: predicted.trainingLabel,
                            date: Date())
        // Small file, written only when the user saves scans — main thread is fine
        // and keeps us inside the target's default MainActor isolation.
        // A JSON array is what MLDataTable(contentsOf:) reads directly.
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]

        var samples: [Sample] = []
        if let data = try? Data(contentsOf: fileURL) {
            samples = (try? decoder.decode([Sample].self, from: data)) ?? []
        }
        samples.append(sample)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        if let data = try? encoder.encode(samples) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }
}
