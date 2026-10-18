//
//  CategoryScreenStandalone.swift
//  hh
//
//  Fix 2: Document thumbnails are now tappable NavigationLinks
//         that navigate to DocumentScreenStandalone (image + editable info).
//

import SwiftUI
import PhotosUI

struct CategoryScreenStandalone: View {
    @EnvironmentObject var vm: HomeViewModel
    let category: CategoryModel

    // Always read latest data
    var currentCategory: CategoryModel {
        vm.globalCategories.first(where: { $0.id == category.id }) ?? category
    }

    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?

    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)

    var body: some View {
        Group {
            if currentCategory.documents.isEmpty {

                ContentUnavailableView {
                    Label("No Documents", systemImage: category.icon)
                } description: {
                    Text("Add photos or files to this category.")
                } actions: {
                    Button("Add Document") {
                        showPhotoPicker = true
                    }
                    .buttonStyle(.borderedProminent)
                }

            } else {

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        // Fix 2: Each thumbnail is a NavigationLink to DocumentScreenStandalone
                        ForEach(currentCategory.documents) { doc in
                            NavigationLink(
                                destination: DocumentScreenStandalone(
                                    document: doc,
                                    category: currentCategory
                                )
                            ) {
                                documentThumbnail(doc)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

            }
        }
        .navigationTitle(category.name)
        .navigationBarTitleDisplayMode(.inline)

        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showPhotoPicker = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add photo")
            }
        }

        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedItem,
            matching: .images
        )

        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }

            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {

                    let fileName = UUID().uuidString + ".jpg"
                    let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent(fileName)

                    if let jpegData = uiImage.jpegData(compressionQuality: 0.8) {
                        try? jpegData.write(to: url)

                        let newDoc = DocumentModel(
                            name: "Document",
                            imageName: fileName,
                            note: "",
                            categoryName: category.name
                        )

                        vm.addDocumentToGlobal(newDoc, category: currentCategory)
                    }
                }

                selectedItem = nil
            }
        }
    }

    // THUMBNAIL
    @ViewBuilder
    func documentThumbnail(_ doc: DocumentModel) -> some View {
        Group {
            if let uiImage = UIImage.thumbnailFromDocuments(named: doc.imageName, maxPixelSize: 400) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .foregroundStyle(.gray)
            }
        }
        // Square cell sized by the grid column (replaces deprecated UIScreen.main).
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .contentShape(Rectangle())
    }

}
