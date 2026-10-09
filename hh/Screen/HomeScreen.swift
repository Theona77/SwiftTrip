//
//  HomeScreen.swift
//  hh
//

import SwiftUI
import PhotosUI

struct HomeScreen: View {
    @EnvironmentObject var vm: HomeViewModel

    @State private var showCreateTrip = false
    @State private var isEditingTrips = false
    @State private var selectedFullImageDoc: DocumentModel?

    @StateObject private var scanner = ScanFlowLauncher()

    private var trimmedSearchText: String {
        vm.searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            if trimmedSearchText.isEmpty { homeContent }
            else { searchResultsContent }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isEditingTrips { addTripButton }
            else {
                BottomActionBar(
                    searchText: $vm.searchText,
                    launcher: scanner
                )
            }
        }
        .sheet(isPresented: $showCreateTrip) {
            CreateTripView { vm.addTrip($0) }
        }
        .scanFlow(scanner)
        // Widget links are handled once, in RootView via DeepLinkHandler.
    }

    private var addTripButton: some View {
        Button { showCreateTrip = true } label: {
            Label("Add Trip", systemImage: "plus")
                .font(.headline).frame(maxWidth: .infinity).padding()
                .background(Color.blue).foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding().background(.ultraThinMaterial)
    }

    private var homeContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Let's Store and Access your \(Text("Travel Documents").foregroundStyle(.blue)) Quickly!")
                    .font(.title2).fontWeight(.semibold).padding(.horizontal)

                Text("Personal Essentials").font(.headline).padding(.horizontal)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(vm.globalCategories) { cat in
                        CategoryFolderCell(category: cat, trip: nil, isEditing: false)
                    }
                }
                .padding(.horizontal)

                tripsSection
                recentSection
                Spacer(minLength: 100)
            }
        }
    }

    private var tripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Trips").font(.headline)
                Spacer()
                Button(isEditingTrips ? "Done" : "Edit") {
                    withAnimation { isEditingTrips.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 18).padding(.vertical, 8)
                .background(isEditingTrips ? Color(.systemGray3) : .blue)
                .foregroundStyle(.white).clipShape(Capsule())
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(vm.filteredTrips) { trip in
                        if isEditingTrips {
                            TripCardView(trip: trip, isEditing: true, onDelete: { vm.removeTrip(trip) })
                        } else {
                            NavigationLink(destination: TripScreen(trip: trip).environmentObject(vm)) {
                                TripCardView(trip: trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recently viewed").font(.headline).padding(.horizontal)
            if vm.recentDocuments.isEmpty {
                Text("No recently viewed documents.")
                    .font(.subheadline).foregroundStyle(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(vm.recentDocuments.prefix(5)) { doc in
                        HStack(spacing: 12) {
                            // Tap image → full screen
                            Button {
                                if UIImage.loadFromDocuments(named: doc.imageName) != nil {
                                    selectedFullImageDoc = doc
                                }
                            } label: {
                                docThumb(doc, size: 44)
                            }
                            .buttonStyle(.plain)

                            // Tap text → document detail
                            NavigationLink(
                                destination: RecentDocumentDetailRouter(document: doc)
                                    .environmentObject(vm)
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.name).font(.subheadline).lineLimit(1)
                                        .foregroundStyle(.primary)
                                    Text(doc.categoryName).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)

                        if doc.id != vm.recentDocuments.prefix(5).last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }
        }
        .fullScreenCover(item: $selectedFullImageDoc) { doc in
            FullImageViewer(document: doc)
        }
    }

    private var searchResultsContent: some View {
        Group {
            if vm.filteredDocuments.isEmpty {
                ContentUnavailableView {
                    Label("No results for \"\(trimmedSearchText)\"", systemImage: "doc.text.magnifyingglass")
                } description: { Text("Check spelling or try a new search.") }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(vm.filteredDocuments) { doc in
                            NavigationLink(destination: RecentDocumentDetailRouter(document: doc).environmentObject(vm)) {
                                searchResultCard(for: doc)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal).padding(.top, 12).padding(.bottom, 120)
                }
            }
        }
    }

    private func documentRow(for doc: DocumentModel) -> some View {
        HStack(spacing: 12) {
            docThumb(doc, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name).font(.subheadline).lineLimit(1)
                Text(doc.categoryName).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    private func searchResultCard(for doc: DocumentModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(sourceName(for: doc))
                .font(.caption.weight(.semibold)).foregroundStyle(.secondary).textCase(.uppercase)
            HStack(spacing: 12) {
                docThumb(doc, size: 58, cornerRadius: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(doc.name).font(.headline).lineLimit(1)
                    Text(doc.categoryName).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 18).fill(Color(.systemBackground)))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color(.systemGray5), lineWidth: 1))
        }
    }

    private func docThumb(_ doc: DocumentModel, size: CGFloat, cornerRadius: CGFloat = 8) -> some View {
        Group {
            if let img = loadImage(named: doc.imageName) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                Image(systemName: "doc.text").foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .background(Color(.systemGray5).clipShape(RoundedRectangle(cornerRadius: cornerRadius)))
    }

    private func sourceName(for doc: DocumentModel) -> String {
        if let trip = vm.trips.first(where: { $0.categories.contains(where: { $0.documents.contains(doc) }) }) {
            return trip.name
        }
        return vm.globalCategories.contains(where: { $0.documents.contains(doc) })
            ? "Personal Essentials" : "Saved Documents"
    }

    private func loadImage(named filename: String) -> UIImage? {
        guard !filename.isEmpty else { return nil }
        if let img = UIImage(contentsOfFile: filename) { return img }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
        return (try? Data(contentsOf: url)).flatMap(UIImage.init)
    }
}
