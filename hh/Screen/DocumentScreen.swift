//
//  DocumentScreen.swift
//  hh
//


import SwiftUI

struct DocumentScreen: View {
    @EnvironmentObject var vm: HomeViewModel
    let document: DocumentModel
    let category: CategoryModel
    let trip: TripModel
    
    @State private var showEditSheet = false
    
    // Fix 6: show full-screen image on tap
    @State private var showFullImage = false
    
    private var ocrFields: [(label: String, value: String)] {
        document.note
            .split(separator: "\n")
            .compactMap { line -> (String, String)? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let label = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : (label, value)
            }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                
                // Fix 6: tapping the image presents full screen
                documentImage
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 24)
                    .onTapGesture {
                        if  UIImage.loadFromDocuments(named: document.imageName) != nil {
                            showFullImage = true
                        }
                    }
                
                Text(document.name)
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                
                if let date = document.startDate {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)))
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                
                if document.startDate != nil || document.endDate != nil {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(document.startDate.map { timeString($0) } ?? "—")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                        Spacer()
                        Image(systemName: "arrow.right")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .padding(.top, 22)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("End")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(document.endDate.map { timeString($0) } ?? "—")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                
                if !ocrFields.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(ocrFields, id: \.label) { field in
                            HStack(alignment: .top) {
                                Text(field.label)
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                    .frame(width: 110, alignment: .leading)
                                Text(field.value)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            if field.label != ocrFields.last?.label {
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                
                if !document.note.isEmpty && ocrFields.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note:")
                            .font(.subheadline.bold())
                        Text(document.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
                
                Spacer(minLength: 120)
            }
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        // Fix 1 — record as recently viewed
        .onAppear {
            vm.recordRecentDocument(document)
        }
        .safeAreaInset(edge: .bottom) {
            Button { showEditSheet = true } label: {
                Text("Edit Information")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sheet(isPresented: $showEditSheet) {
            EditDocumentView(document: document) { updated in
                vm.updateDocument(updated, in: category, trip: trip)
            }
        }
        // Fix 6 — full screen image viewer
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageViewer(image:  UIImage.loadFromDocuments(named: document.imageName))
        }
    }
    
    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }
    
    @ViewBuilder
    private var documentImage: some View {
        if let uiImage = UIImage.loadFromDocuments(named: document.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .padding(8)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                        .padding(10)
                }
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.systemGray5))
                .frame(height: 200)
                .overlay {
                    Image(systemName: "doc.text.image")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

// MARK: - Full Image Viewer (Fix 6)

struct FullImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage?

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding()
        }
    }
}

// MARK: - Edit Document Form (unchanged)

struct EditDocumentView: View {
    @Environment(\.dismiss) private var dismiss
    var document: DocumentModel
    var onSave: (DocumentModel) -> Void

    @State private var name: String
    @State private var note: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var hasStartDate: Bool
    @State private var hasEndDate: Bool

    init(document: DocumentModel, onSave: @escaping (DocumentModel) -> Void) {
        self.document = document
        self.onSave = onSave
        _name         = State(initialValue: document.name)
        _note         = State(initialValue: document.note)
        _startDate    = State(initialValue: document.startDate ?? Date())
        _endDate      = State(initialValue: document.endDate   ?? Date())
        _hasStartDate = State(initialValue: document.startDate != nil)
        _hasEndDate   = State(initialValue: document.endDate   != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Document Name") {
                    TextField("e.g. Dufan Ticket", text: $name)
                }
                Section("Start") {
                    Toggle("Has Start", isOn: $hasStartDate.animation())
                    if hasStartDate {
                        DatePicker("Date", selection: $startDate, displayedComponents: .date)
                        DatePicker("Time", selection: $startDate, displayedComponents: .hourAndMinute)
                    }
                }
                Section("End") {
                    Toggle("Has End", isOn: $hasEndDate.animation())
                    if hasEndDate {
                        DatePicker("Date", selection: $endDate, displayedComponents: .date)
                        DatePicker("Time", selection: $endDate, displayedComponents: .hourAndMinute)
                    }
                }
                Section("Notes") {
                    TextField("Add a note…", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Edit Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updated       = document
                        updated.name      = name
                        updated.note      = note
                        updated.startDate = hasStartDate ? startDate : nil
                        updated.endDate   = hasEndDate   ? endDate   : nil
                        onSave(updated)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
