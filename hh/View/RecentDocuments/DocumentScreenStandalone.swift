//
//  DocumentScreenStandalone.swift
//  hh
//
//  Created by Theona Arlinton on 20/04/26.
//



import SwiftUI

// MARK: - DocumentScreenStandalone
// Used for documents in globalCategories (Personal Essentials) and recent documents.

struct DocumentScreenStandalone: View {
    @EnvironmentObject var vm: HomeViewModel
    let document: DocumentModel
    let category: CategoryModel

    @State private var showEditSheet = false
    @State private var showFullImage = false

    private var currentDoc: DocumentModel {
        guard
            let cIdx = vm.globalCategories.firstIndex(where: { $0.id == category.id }),
            let doc = vm.globalCategories[cIdx].documents.first(where: { $0.id == document.id })
        else { return document }
        return doc
    }

    private var ocrFields: [(label: String, value: String)] {
        currentDoc.note
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

                // Tappable image → fullscreen
                documentImage
                    .padding(.horizontal)
                    .padding(.top)
                    .padding(.bottom, 24)
                    .onTapGesture {
                        if UIImage.loadFromDocuments(named: currentDoc.imageName) != nil {
                            showFullImage = true
                        }
                    }

                Text(currentDoc.name)
                    .font(.title2.bold())
                    .padding(.horizontal)
                    .padding(.bottom, 20)

                if let date = currentDoc.startDate {
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

                if currentDoc.startDate != nil || currentDoc.endDate != nil {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Start")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(currentDoc.startDate.map { timeString($0) } ?? "—")
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
                            Text(currentDoc.endDate.map { timeString($0) } ?? "—")
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

                if !currentDoc.note.isEmpty && ocrFields.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Note:")
                            .font(.subheadline.bold())
                        Text(currentDoc.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }

                Spacer(minLength: 120)
            }
        }
        .navigationTitle(currentDoc.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            vm.recordRecentDocument(currentDoc)
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
            EditDocumentView(document: currentDoc) { updated in
                vm.updateDocumentInGlobal(updated, category: category)
            }
        }
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageViewer(image: UIImage.loadFromDocuments(named: currentDoc.imageName))
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    @ViewBuilder
    private var documentImage: some View {
        if let uiImage = UIImage.loadFromDocuments(named: currentDoc.imageName) {
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

// MARK: - RecentDocumentDetailView
// Fix 4: For recent documents that might belong to a trip OR personal essentials.
// We try to resolve origin and route appropriately.

struct RecentDocumentDetailRouter: View {
    @EnvironmentObject var vm: HomeViewModel
    let document: DocumentModel

    /// Resolve where this document lives
    private var resolved: ResolvedDocSource? {
        // Check global categories first
        for cat in vm.globalCategories {
            if cat.documents.contains(where: { $0.id == document.id }) {
                return .global(category: cat)
            }
        }
        // Check trips
        for trip in vm.trips {
            for cat in trip.categories {
                if cat.documents.contains(where: { $0.id == document.id }) {
                    return .trip(trip: trip, category: cat)
                }
            }
        }
        return nil
    }

    var body: some View {
        Group {
            switch resolved {
            case .global(let category):
                DocumentScreenStandalone(document: document, category: category)
            case .trip(let trip, let category):
                DocumentScreen(document: document, category: category, trip: trip)
            case nil:
                // Fallback: show read-only with the info we have
                UnresolvedDocumentView(document: document)
            }
        }
    }

    private enum ResolvedDocSource {
        case global(category: CategoryModel)
        case trip(trip: TripModel, category: CategoryModel)
    }
}

// MARK: - Fallback read-only view when source can't be resolved

struct UnresolvedDocumentView: View {
    let document: DocumentModel
    @State private var showFullImage = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let img = UIImage.loadFromDocuments(named: document.imageName) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                        .onTapGesture { showFullImage = true }
                }
                Text(document.name)
                    .font(.title2.bold())
                    .padding(.horizontal)
                if !document.note.isEmpty {
                    Text(document.note)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
            }
            .padding(.top)
        }
        .navigationTitle(document.name)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageViewer(image: UIImage.loadFromDocuments(named: document.imageName))
        }
    }
}
