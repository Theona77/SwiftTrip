//
//  TripScreen.swift
//  hh
//

import SwiftUI
import PhotosUI

private struct TripDocumentSearchResult: Identifiable {
    let document: DocumentModel
    let category: CategoryModel

    var id: UUID { document.id }
}

struct TripScreen: View {
    @EnvironmentObject var vm: HomeViewModel
    let trip: TripModel

    @State private var showCreateCategory = false
    @State private var isEditing = false
    @State private var searchText = ""

    @State private var isEditingName = false
    @State private var draftName = ""
    @FocusState private var nameFocused: Bool

    @State private var isEditingDescription = false
    @State private var draftDescription = ""
    @FocusState private var descFocused: Bool

    @StateObject private var scanner = ScanFlowLauncher()

    var currentTrip: TripModel {
        vm.trips.first(where: { $0.id == trip.id }) ?? trip
    }

    private var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredCategories: [CategoryModel] {
        currentTrip.categories
    }

    private var filteredDocuments: [TripDocumentSearchResult] {
        guard !trimmedSearchText.isEmpty else { return [] }

        return currentTrip.categories.flatMap { category in
            category.documents.compactMap { doc in
                let matches =
                    category.name.localizedCaseInsensitiveContains(trimmedSearchText) ||
                    doc.name.localizedCaseInsensitiveContains(trimmedSearchText) ||
                    doc.categoryName.localizedCaseInsensitiveContains(trimmedSearchText) ||
                    doc.note.localizedCaseInsensitiveContains(trimmedSearchText)

                return matches ? TripDocumentSearchResult(document: doc, category: category) : nil
            }
        }
    }

    let columns = Array(repeating: GridItem(.flexible(), spacing: 16), count: 3)

    var body: some View {
        Group {
            if trimmedSearchText.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        nameField
                        statusRow
                        categoryGrid
                        descriptionSection
                        Spacer(minLength: 100)
                    }
                    .padding(.top)
                }
            } else {
                tripSearchResultsContent
            }
        }
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") { withAnimation { isEditing.toggle() } }
                    .buttonStyle(.borderedProminent)
                    .tint(isEditing ? .gray : .blue)
                    .controlSize(.small)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isEditing {
                Button { showCreateCategory = true } label: {
                    Label("Add Category", systemImage: "plus")
                        .font(.headline).frame(maxWidth: .infinity).padding()
                        .background(Color.blue).foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding().background(.ultraThinMaterial)
            } else {
                BottomActionBar(
                    searchText: $searchText,
                    launcher: scanner
                )
            }
        }
        .sheet(isPresented: $showCreateCategory) {
            CreateCategoryView { name, icon in
                vm.addCategory(CategoryModel(name: name, icon: icon, documents: []), to: currentTrip)
            }
        }
        .scanFlow(scanner, tripID: currentTrip.id)
    }

    // MARK: - Subviews

    private var nameField: some View {
        Group {
            if isEditingName {
                TextField("Trip name", text: $draftName)
                    .font(.title2.bold()).focused($nameFocused)
                    .submitLabel(.done).onSubmit { commitName() }
                    .padding(.horizontal).onAppear { nameFocused = true }
            } else {
                HStack {
                    Text(currentTrip.name).font(.title2.bold())
                    Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal).contentShape(Rectangle())
                .onTapGesture { draftName = currentTrip.name; isEditingName = true }
            }
        }
    }

    private var statusRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(currentTrip.upcomingOpt).font(.caption.bold()).foregroundStyle(.blue)
            Text("\(currentTrip.startDate, style: .date) – \(currentTrip.endDate, style: .date)")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(filteredCategories) { cat in
                CategoryFolderCell(category: cat, trip: currentTrip, isEditing: isEditing)
            }
        }
        .padding(.horizontal)
    }

    private var tripSearchResultsContent: some View {
        Group {
            if filteredDocuments.isEmpty {
                ContentUnavailableView {
                    Label("No results for \"\(trimmedSearchText)\"", systemImage: "doc.text.magnifyingglass")
                } description: {
                    Text("Check spelling or try a new search.")
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(filteredDocuments) { result in
                            NavigationLink(
                                destination: DocumentScreen(
                                    document: result.document,
                                    category: result.category,
                                    trip: currentTrip
                                )
                            ) {
                                tripSearchResultCard(for: result)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    private func tripSearchResultCard(for result: TripDocumentSearchResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.category.name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                tripSearchThumbnail(for: result.document)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.document.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(result.document.categoryName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
        }
    }

    private func tripSearchThumbnail(for doc: DocumentModel) -> some View {
        Group {
            if let img = loadImage(named: doc.imageName) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .background(Color(.systemGray5).clipShape(RoundedRectangle(cornerRadius: 12)))
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Description").font(.headline).padding(.horizontal)
            if isEditingDescription {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $draftDescription)
                        .focused($descFocused).font(.subheadline).foregroundStyle(.secondary)
                        .frame(minHeight: 80).padding(8)
                        .background(Color(.systemGray6)).clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal).onAppear { descFocused = true }
                    HStack {
                        Spacer()
                        Button("Done") { commitDescription() }.font(.subheadline.bold()).padding(.horizontal)
                    }
                }
            } else {
                HStack(alignment: .top) {
                    Text(currentTrip.description.isEmpty ? "Tap to add a description…" : currentTrip.description)
                        .font(.subheadline)
                        .foregroundStyle(currentTrip.description.isEmpty ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.secondary))
                    Spacer()
                    Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal).contentShape(Rectangle())
                .onTapGesture { draftDescription = currentTrip.description; isEditingDescription = true }
            }
        }
    }

    private func commitName() {
        let t = draftName.trimmingCharacters(in: .whitespaces)
        if !t.isEmpty { vm.renameTrip(currentTrip, to: t) }
        isEditingName = false
    }

    private func commitDescription() {
        vm.updateTripDescription(currentTrip, to: draftDescription)
        isEditingDescription = false
    }

    private func loadImage(named filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        if let img = UIImage(contentsOfFile: filename) { return img }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        return (try? Data(contentsOf: url)).flatMap(UIImage.init)
    }
}

// MARK: - CategoryFolderCell

struct CategoryFolderCell: View {
    @EnvironmentObject var vm: HomeViewModel
    let category: CategoryModel
    let trip: TripModel?
    let isEditing: Bool

    private var hasDocuments: Bool { !category.documents.isEmpty }

    private var accentColor: Color {
        switch category.name {
        case "ID":           return Color(hex: "#3478F6") ?? .blue
        case "Passport":     return Color(hex: "#30B0C7") ?? .blue
        case "VISA":         return Color(hex: "#5856D6") ?? .blue
        case "Flight":       return Color(hex: "#FF9F0A") ?? .orange
        case "Hotel":        return Color(hex: "#FF6B35") ?? .orange
        case "Trains":       return Color(hex: "#30B0C7") ?? .blue
        case "Reservations": return Color(hex: "#BF5AF2") ?? .purple
        case "Activities":   return Color(hex: "#34C759") ?? .green
        case "Events":       return Color(hex: "#FF375F") ?? .red
        default:             return Color(hex: "#8E8E93") ?? .gray
        }
    }

    var body: some View {
        NavigationLink {
            if let trip { CategoryScreen(category: category, trip: trip) }
            else { CategoryScreenStandalone(category: category) }
        } label: {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(hasDocuments ? accentColor.opacity(0.12) : Color(.systemGray5))
                        .frame(height: 90)

                    VStack(spacing: 6) {
                        Image(systemName: category.icon).font(.title2)
                            .foregroundStyle(hasDocuments ? accentColor : .primary)
                        Text(category.documents.isEmpty ? "Empty" : "\(category.documents.count) items")
                            .font(.caption2)
                            .foregroundStyle(hasDocuments ? accentColor : .secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if isEditing, let trip {
                        Button { vm.removeCategory(category, from: trip) } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                                .background(Color.white.clipShape(Circle()))
                        }
                        .offset(x: 6, y: -6)
                    }
                }

                Text(category.name).font(.caption).lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let trip {
                Button(role: .destructive) { vm.removeCategory(category, from: trip) } label: {
                    Label("Remove", systemImage: "trash")
                }
            }
        }
    }
}
