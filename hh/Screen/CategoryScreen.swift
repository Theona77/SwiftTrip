//
//  CategoryScreen.swift
//  hh
//
//  Created by Theona Arlinton on 19/04/26.
//

import SwiftUI
import PhotosUI

struct CategoryScreen: View {
    @EnvironmentObject var vm: HomeViewModel
    let category: CategoryModel
    let trip: TripModel

    // Always read fresh
    var currentCategory: CategoryModel {
        let t = vm.trips.first(where: { $0.id == trip.id }) ?? trip
        return t.categories.first(where: { $0.id == category.id }) ?? category
    }

    @State private var showPhotoPicker = false
    @State private var selectedItem: PhotosPickerItem?

    let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 3)
    let cellSize = UIScreen.main.bounds.width / 3

    var body: some View {
        Group {
            if currentCategory.documents.isEmpty {
                // Empty state
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
                            NavigationLink(
                                destination: DocumentScreen(document: doc, category: currentCategory, trip: trip)
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
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }

            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {

                    // Save to local storage
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

                        vm.addDocument(newDoc, to: currentCategory, in: trip)
                    }
                }

                selectedItem = nil
            }
        }
    }

    @ViewBuilder
    func documentThumbnail(_ doc: DocumentModel) -> some View {
        Group {
            if let uiImage =  UIImage.loadFromDocuments(named: doc.imageName) {
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
        .frame(width: cellSize, height: cellSize)
        .clipped()
    }

}
