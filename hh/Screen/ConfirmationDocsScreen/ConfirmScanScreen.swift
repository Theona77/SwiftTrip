//
//  ConfirmScanScreen.swift
//  hh
//

import SwiftUI


// MARK: - Main screen

struct ConfirmScanScreen: View {

    @ObservedObject var store: ScanStore
    var onSaveCurrent: (ScannedDocument) -> Void
    var onDiscard: () -> Void
    var onRetake: () -> Void

    private var doc: ScannedDocument? { store.currentDoc }
    private var docIndex: Int         { store.currentIndex }
    private var isProcessing: Bool    { doc?.isProcessing ?? true }

    var body: some View {
        List {

            // ── Captured preview ────────────────────────────────────
            Section {
                if let doc {
                    if doc.isProcessing {
                        HStack {
                            Spacer()
                            VStack(spacing: 10) {
                                ProgressView()
                                Text("Scanning document…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 40)
                            Spacer()
                        }
                        .listRowBackground(Color(.systemGroupedBackground))
                    } else {
                        Image(uiImage: doc.image)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .listRowInsets(EdgeInsets(top: 12, leading: 16,
                                                      bottom: 12, trailing: 16))
                    }
                }
            } header: {
                HStack {
                    Text("Captured Preview")
                    Spacer()
                    Button("Retake") { onRetake() }
                        .font(.subheadline)
                        .buttonStyle(.borderless)
                        .tint(.blue)
                }
            } footer: {
                if store.totalCount > 1, let doc {
                    Text(doc.ticketLabel)
                }
            }

            // ── Multi-doc strip ─────────────────────────────────────
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

            // ── Identified content ──────────────────────────────────
            if let doc, !doc.isProcessing {
                Section("Identified Content") {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(doc.category.rawValue)
                                .font(.headline)
                            Text(doc.category.isPersonalEssential
                                 ? "Saved to Personal Essentials"
                                 : "Saved to a Trip Card")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: doc.category.icon)
                            .foregroundStyle(Color(hex: doc.category.colorHex) ?? .blue)
                    }
                }

                // ── Category picker ─────────────────────────────────
                Section("Auto Categorization") {
                    Picker("Category", selection: categoryBinding(for: docIndex)) {
                        ForEach(DocumentCategory.allCases) { cat in
                            Label(cat.rawValue, systemImage: cat.icon).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Confirm Document")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { onDiscard() } label: { Image(systemName: "xmark") }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                // Primary
                Button {
                    if let doc { onSaveCurrent(doc) }
                } label: {
                    let label = store.totalCount > 1 ? "Next" : "Save Document"
                    let bg: Color = isProcessing ? Color(.systemGray4) : .accentColor
                    Text(label)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(bg)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(isProcessing)

                // Destructive
                Button(role: .destructive) {
                    onDiscard()
                } label: {
                    Text("Discard Document")
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

    private func categoryBinding(for index: Int) -> Binding<DocumentCategory> {
        Binding(
            get: { store.scannedDocs[index].category },
            set: { store.setCategory($0, at: index) }
        )
    }
}

// MARK: - Identified Content Badge

struct IdentifiedContentBadge: View {
    let category: DocumentCategory

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text("Identified as")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(category.rawValue)
                    .font(.headline)
            }
        } icon: {
            Image(systemName: category.icon)
                .foregroundStyle(Color(hex: category.colorHex) ?? .blue)
                .font(.title3)
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Color hex helper

extension Color {
    init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.hasPrefix("#") ? String(s.dropFirst()) : s
        guard s.count == 6, let val = UInt64(s, radix: 16) else { return nil }
        self.init(
            red:   Double((val >> 16) & 0xFF) / 255,
            green: Double((val >> 8)  & 0xFF) / 255,
            blue:  Double( val        & 0xFF) / 255
        )
    }
}
