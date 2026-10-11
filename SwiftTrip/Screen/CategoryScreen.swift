//  CategoryScreen.swift
import SwiftUI
import PhotosUI
import PDFKit

struct CategoryScreen: View {
    @EnvironmentObject var vm: HomeViewModel
    let category: CategoryModel
    let trip: TripModel

    var currentCategory: CategoryModel {
        let t = vm.trips.first(where: { $0.id == trip.id }) ?? trip
        return t.categories.first(where: { $0.id == category.id }) ?? category
    }

    @State private var showPhotoPicker  = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showCamera       = false
    @State private var showFileImporter = false
    @State private var isSelecting      = false
    @State private var selectedDocIDs   = Set<UUID>()
    @State private var showDeleteAlert  = false

    let columns  = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    let cellSize = UIScreen.main.bounds.width / 3

    var body: some View {
        Group {
            if currentCategory.documents.isEmpty {
                ContentUnavailableView {
                    Label("No Documents", systemImage: category.icon)
                } description: {
                    Text("Add photos or files to this category.")
                } actions: {
                    Button("Add Document") { showPhotoPicker = true }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(currentCategory.documents) { doc in
                            ZStack(alignment: .topLeading) {
                                Group {
                                    if isSelecting {
                                        documentThumbnail(doc)
                                            .onTapGesture { toggleSelection(doc) }
                                            .accessibilityElement()
                                            .accessibilityLabel(doc.name)
                                            .accessibilityAddTraits(selectedDocIDs.contains(doc.id)
                                                                    ? [.isButton, .isSelected] : .isButton)
                                            .accessibilityHint("Selects this document")
                                    } else {
                                        NavigationLink(
                                            destination: DocumentScreen(
                                                document: doc,
                                                category: currentCategory,
                                                trip: trip
                                            )
                                        ) {
                                            documentThumbnail(doc)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel(doc.name)
                                    }
                                }
                                .onLongPressGesture {
                                    if !isSelecting {
                                        isSelecting = true
                                        selectedDocIDs.insert(doc.id)
                                    }
                                }

                                if isSelecting {
                                    Image(
                                        systemName: selectedDocIDs.contains(doc.id)
                                            ? "checkmark.circle.fill" : "circle"
                                    )
                                    .foregroundStyle(
                                        selectedDocIDs.contains(doc.id) ? .blue : .white
                                    )
                                    .shadow(radius: 1)
                                    .padding(6)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(isSelecting ? "\(selectedDocIDs.count) Selected" : category.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isSelecting {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isSelecting = false
                        selectedDocIDs = []
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Delete") { showDeleteAlert = true }
                        .foregroundStyle(.red)
                        .disabled(selectedDocIDs.isEmpty)
                }
            } else {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button { showCamera = true } label: {
                            Label("Camera", systemImage: "camera")
                        }
                        Button { showPhotoPicker = true } label: {
                            Label("Photos", systemImage: "photo.on.rectangle")
                        }
                        Button { showFileImporter = true } label: {
                            Label("Files / PDF", systemImage: "folder")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add document")
                }
            }
        }
        .alert("Delete \(selectedDocIDs.count) document(s)?", isPresented: $showDeleteAlert) {
            Button("Delete", role: .destructive) { deleteSelected() }
            Button("Cancel", role: .cancel) {}
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run { saveImage(uiImage) }
                }
                selectedItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView { img in saveImage(img) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.image, .jpeg, .png, .pdf],
            allowsMultipleSelection: true,
            onCompletion: handleFileImport
        )
    }

    // MARK: - Thumbnail

    @ViewBuilder
    func documentThumbnail(_ doc: DocumentModel) -> some View {
        Group {
            if let img = UIImage.loadFromDocuments(named: doc.imageName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable().scaledToFit().padding().foregroundStyle(.gray)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipped()
    }

    // MARK: - Actions

    private func toggleSelection(_ doc: DocumentModel) {
        if selectedDocIDs.contains(doc.id) {
            selectedDocIDs.remove(doc.id)
        } else {
            selectedDocIDs.insert(doc.id)
        }
    }

    private func deleteSelected() {
        let toDelete = currentCategory.documents.filter { selectedDocIDs.contains($0.id) }
        for doc in toDelete {
            vm.removeImageFile(named: doc.imageName)
            if let pdf = doc.pdfFilename { vm.removeImageFile(named: pdf) }
            vm.removeDocument(doc, from: currentCategory, in: trip)
        }
        isSelecting = false
        selectedDocIDs = []
    }

    private func saveImage(_ image: UIImage) {
        let fileName = UUID().uuidString + ".jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url)
            let doc = DocumentModel(
                name: "Document", imageName: fileName,
                note: "", categoryName: category.name
            )
            vm.addDocument(doc, to: currentCategory, in: trip)
        }
    }

    private func savePDF(from sourceURL: URL) {
        let pdfName = UUID().uuidString + ".pdf"
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docsDir.appendingPathComponent(pdfName)
        guard let pdfData = try? Data(contentsOf: sourceURL) else { return }
        try? pdfData.write(to: destURL)

        guard
            let firstPage = UIImage.renderPDFFirstPage(from: destURL),
            let jpegData  = firstPage.jpegData(compressionQuality: 0.8)
        else { return }

        let imgName = UUID().uuidString + ".jpg"
        try? jpegData.write(to: docsDir.appendingPathComponent(imgName))

        let doc = DocumentModel(
            name: "Document", imageName: imgName,
            note: "", categoryName: category.name,
            pdfFilename: pdfName
        )
        vm.addDocument(doc, to: currentCategory, in: trip)
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            if url.pathExtension.lowercased() == "pdf" {
                savePDF(from: url)
            } else if let data = try? Data(contentsOf: url),
                      let image = UIImage(data: data) {
                saveImage(image)
            }
        }
    }
}
