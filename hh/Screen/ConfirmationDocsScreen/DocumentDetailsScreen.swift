//
//  DocumentDetailsScreen.swift
//  hh
//

import SwiftUI

// MARK: - Main screen

struct DocumentDetailsScreen: View {

    @ObservedObject var store: ScanStore
    let tripID: UUID?
    let categoryName: String?
    var onBack: (() -> Void)? = nil
    var onDidSave: (() -> Void)? = nil

    @EnvironmentObject var vm: HomeViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editableFields: [(label: String, value: String)] = []
    @State private var isEditing       = false
    @State private var isSaved         = false
    @State private var showDiscard     = false
    @State private var selectedTripID: UUID?

    private var scannedDoc: ScannedDocument? { store.currentDoc }
    private var hasPendingOCR: Bool { store.scannedDocs.contains { $0.isProcessing } }

    var body: some View {
        List {
            if let scannedDoc {

                // ── Preview ──────────────────────────────────────────
                Section("Captured Preview") {
                    TapToZoomImage(image: scannedDoc.image, pdfData: scannedDoc.pdfData)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16,
                                                  bottom: 12, trailing: 16))

                    if scannedDoc.ocrData.rawText.count > 2 {
                        IdentifiedContentBadge(category: scannedDoc.category)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16,
                                                       bottom: 12, trailing: 16))
                            .listRowBackground(Color.clear)
                    }
                }

                // ── Multi-doc strip ──────────────────────────────────
                if store.totalCount > 1 {
                    Section("All Scanned Documents") {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(store.scannedDocs.indices, id: \.self) { i in
                                    ScannedDocThumbnail(
                                        doc: store.scannedDocs[i],
                                        index: i,
                                        isSelected: store.currentIndex == i,
                                        onTap: { store.currentIndex = i }
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // ── Extracted information ────────────────────────────
                Section {
                    if editableFields.isEmpty {
                        Text("No data extracted")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(editableFields.indices, id: \.self) { i in
                            if isEditing {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(editableFields[i].label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    TextField("", text: $editableFields[i].value)
                                        .font(.subheadline)
                                }
                            } else {
                                LabeledContent(editableFields[i].label) {
                                    Text(editableFields[i].value)
                                        .font(.subheadline)
                                        .multilineTextAlignment(.trailing)
                                }
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Extracted Information")
                        Spacer()
                        Button(isEditing ? "Done" : "Edit") {
                            withAnimation { isEditing.toggle() }
                        }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                        .tint(.blue)
                    }
                }

                // ── Save destination ─────────────────────────────────
                Section("Will Be Saved To") {
                    destinationRow(for: scannedDoc)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Document Details")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    onBack?()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                }
            }
        }
        .onAppear { syncFromCurrentDocument() }
        .onChange(of: store.currentIndex) { _, _ in syncFromCurrentDocument() }
        .alert("Move to Trash?", isPresented: $showDiscard) {
            Button("Move to Trash", role: .destructive) { dismiss() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This document will be permanently removed.")
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {

                // Primary save
                Button { saveDocuments() } label: {
                    let title: String = {
                        if isSaved { return "Saved ✓" }
                        return store.totalCount > 1 ? "Save All Documents" : "Save Document"
                    }()
                    let icon = isSaved ? "checkmark.circle.fill" : "square.and.arrow.down"
                    let bg: Color = isSaved ? .green : hasPendingOCR ? Color(.systemGray4) : .accentColor

                    Label(title, systemImage: icon)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(bg)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(hasPendingOCR || isSaved)

                // Destructive
                Button(role: .destructive) {
                    showDiscard = true
                } label: {
                    Text("Move to Trash")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(.systemGray6))
                        .foregroundStyle(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 24)
            .background(.regularMaterial)
        }
    }

    // MARK: - Destination row

    @ViewBuilder
    private func destinationRow(for scannedDoc: ScannedDocument) -> some View {
        let cat = scannedDoc.category
        if cat.isPersonalEssential {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Personal Essentials").font(.subheadline.bold())
                    Text(cat.rawValue).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: cat.icon)
                    .foregroundStyle(Color(hex: cat.colorHex) ?? .blue)
            }
        } else {
            let tripCat = categoryName ?? cat.tripCategoryName ?? cat.rawValue
            VStack(alignment: .leading, spacing: 12) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDestinationTitle).font(.subheadline.bold())
                        Text("Category: \(tripCat)").font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: cat.icon)
                        .foregroundStyle(Color(hex: cat.colorHex) ?? .blue)
                }

                Menu {
                    ForEach(vm.sortedTrips) { trip in
                        Button(trip.name) { selectedTripID = trip.id }
                    }
                    Button("New Trip Card") { selectedTripID = nil }
                } label: {
                    HStack {
                        Text("Trip Card").foregroundStyle(.secondary)
                        Spacer()
                        Text(selectedDestinationTitle).foregroundStyle(.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    // MARK: - State sync

    private func syncFromCurrentDocument() {
        guard let doc = store.currentDoc else { return }
        editableFields = doc.ocrData.extractedFields
        isEditing      = false
        isSaved        = false
        selectedTripID = tripID ?? vm.nearestTripID
    }

    // MARK: - Save

    private func saveDocuments() {
        let docs = store.scannedDocs
        guard !docs.isEmpty else { return }

        let sharedTripID: UUID? = {
            if let id = selectedTripID { return id }
            guard docs.contains(where: { !$0.category.isPersonalEssential }) else { return nil }
            return vm.createTripCard().id
        }()

        for doc in docs {
            let fields = (doc.id == scannedDoc?.id) ? editableFields : doc.ocrData.extractedFields
            persistDocument(doc, fields: fields, targetTripID: sharedTripID)
            TrainingSampleRecorder.shared.record(text: doc.ocrData.rawText,
                                                 confirmed: doc.category,
                                                 predicted: doc.predictedCategory)
        }

        vm.refreshWidget()
        withAnimation { isSaved = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { onDidSave?() }
    }

    private func persistDocument(_ scannedDoc: ScannedDocument,
                                 fields: [(label: String, value: String)],
                                 targetTripID: UUID?) {
        let name = scannedDoc.ocrData.fullName
            ?? scannedDoc.ocrData.documentTitle
            ?? scannedDoc.category.rawValue

        let filename = saveImageToDisk(scannedDoc.image)
        let pdfFilename = scannedDoc.pdfData.flatMap(savePDFToDisk)
        let noteText = fields.map { "\($0.label): \($0.value)" }.joined(separator: "\n")

        let docModel = DocumentModel(
            name: name, imageName: filename, note: noteText,
            startDate: nil, endDate: nil,
            categoryName: scannedDoc.category.rawValue,
            pdfFilename: pdfFilename
        )

        let cat = scannedDoc.category
        if cat.isPersonalEssential {
            vm.addPersonalDocumentToGlobalCategory(docModel, detectedCategory: cat)
        } else if let targetTripID {
            let catName = categoryName ?? cat.tripCategoryName ?? cat.rawValue
            vm.addDocument(docModel, toCategoryNamed: catName, inTripID: targetTripID)
        } else {
            let catName = cat.tripCategoryName ?? cat.rawValue
            vm.createTripCardAndAddDocument(docModel, categoryName: catName)
        }

        vm.recordRecentDocument(docModel)
    }

    /// Keeps the original PDF so every page can be viewed later.
    private func savePDFToDisk(_ data: Data) -> String? {
        let filename = UUID().uuidString + ".pdf"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return filename
        } catch {
            return nil
        }
    }

    private func saveImageToDisk(_ image: UIImage) -> String {
        let filename = UUID().uuidString + ".jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.85) { try? data.write(to: url) }
        return filename
    }

    private var selectedDestinationTitle: String {
        guard let id = selectedTripID,
              let trip = vm.trips.first(where: { $0.id == id })
        else { return "New Trip Card" }
        return trip.name
    }
}

// MARK: - Extracted Field Row

struct ExtractedFieldRow: View {
    let label: String
    @Binding var value: String
    let isEditing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            if isEditing {
                TextField("", text: $value).font(.subheadline).textFieldStyle(.roundedBorder)
            } else {
                Text(value).font(.subheadline).foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
