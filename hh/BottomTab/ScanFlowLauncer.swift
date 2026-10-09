//
//  ScanFlowLauncher.swift
//  hh
//
//  Encapsulates all scan flow state and sheet/picker presentation
//  that was duplicated between HomeScreen and TripScreen.
//
//  Usage:
//    @StateObject private var scanner = ScanFlowLauncher()
//
//    // In body modifiers:
//    .modifier(ScanFlowModifier(launcher: scanner, tripID: currentTrip.id))
//
//    // To trigger:
//    scanner.show(source: .camera)
//    scanner.show(source: .photos)
//    scanner.show(source: .files)
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Combine

@MainActor

// butuh reference type, tidak boleh ter copy
// Home punya launcher A
// Sheet punya launcher B
// B tidak tahu images dari A
// final artinya class ini tidak boleh diwarisi (inherit)
final class ScanFlowLauncher: ObservableObject {
    
    // UI Triggers
    // showScanFlow → buka sheet utama (ScanFlowCoordinator)
    // photoItems → hasil selection dari Photos picker
    @Published var showScanFlow    = false
    @Published var showCamera      = false
    @Published var showPhotos      = false
    @Published var showFiles       = false
    @Published var photoItems: [PhotosPickerItem] = []

    
    // Bisa dibaca dari luar
    // pendingInputs → buffer gambar/PDF sebelum masuk ke scan flow
    private(set) var source: ScanFlowCoordinator.Source = .photos
    private(set) var pendingInputs: [ScanInput] = []

    // Entry point utama untuk memulai flow
    func show(source: ScanFlowCoordinator.Source) {
        self.source = source
        switch source {
        case .camera: showCamera = true
        case .photos: showPhotos = true
        case .files:  showFiles  = true
        }
    }

    // Untuk simpan images
    // Masuk ke tahap berikutnya setelah gambar sudah ada
    // Flow:
    // validasi (jangan kosong)
    // simpan ke pendingInputs
    // trigger showScanFlow = true
    
    func launch(with images: [UIImage]) {
        launch(inputs: images.map { ScanInput(image: $0) })
    }

    func launch(inputs: [ScanInput]) {
        guard !inputs.isEmpty else { return }
        pendingInputs = inputs
        showScanFlow  = true
    }

    func reset() {
        pendingInputs = []
    }
    
    // Convert hasil PhotosPicker → UIImage → langsung launch flow
    // Kenapa async + TaskGroup?
    // Karena:
    // - loading image dari PhotosPicker itu async
    // - bisa banyak item
    // - ingin parallel processing (biar cepat)

    func loadAndLaunch(_ items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        await withTaskGroup(of: UIImage?.self) { group in
            for item in items {
                group.addTask {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else { return nil }
                    
                    //compress file ke lebih kecil
                    return await image.downsampledForOCR()
                }
            }
            // paralel
            for await image in group {
                if let image { loaded.append(image) }
            }
        }
        photoItems = []
        launch(with: loaded)
    }

    func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        // Images and PDFs — a PDF becomes one document with all its pages.
        let inputs = urls.compactMap { url -> ScanInput? in
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }
            return ScanInput.load(from: url)
        }
        launch(inputs: inputs)
    }
}

// MARK: - View Modifier

struct ScanFlowModifier: ViewModifier {
    @ObservedObject var launcher: ScanFlowLauncher
    @EnvironmentObject var vm: HomeViewModel
    var tripID: UUID?   // nil = HomeScreen (no trip context)

    func body(content: Content) -> some View {
        content
            // No dialog needed — menu is on the BottomActionBar button directly
            // Scan flow sheet
            .sheet(isPresented: $launcher.showScanFlow, onDismiss: { launcher.reset() }) {
                if let tripID {
                    ScanFlowCoordinator(
                        source: launcher.source,
                        tripID: tripID,
                        initialInputs: launcher.pendingInputs,
                        launchSourceOnAppear: false
                    )
                    .environmentObject(vm)
                } else {
                    ScanFlowCoordinator(
                        source: launcher.source,
                        initialInputs: launcher.pendingInputs,
                        launchSourceOnAppear: false
                    )
                    .environmentObject(vm)
                }
            }
            // Camera
            .fullScreenCover(isPresented: $launcher.showCamera) {
                CameraPickerView { img in launcher.launch(with: [img]) }
            }
            // Photos picker
            .photosPicker(
                isPresented: $launcher.showPhotos,
                selection: $launcher.photoItems,
                maxSelectionCount: 10,
                matching: .images
            )
            .onChange(of: launcher.photoItems) { _, items in
                guard !items.isEmpty else { return }
                Task { await launcher.loadAndLaunch(items) }
            }
        
        
        // MARK: - Import File
            .fileImporter(
                isPresented: $launcher.showFiles,
                allowedContentTypes: [.image, .pdf],
                allowsMultipleSelection: true,
                onCompletion: launcher.handleFileImport
            )
    }
}

// MARK: - Convenience extension

extension View {
    func scanFlow(_ launcher: ScanFlowLauncher, tripID: UUID? = nil) -> some View {
        modifier(ScanFlowModifier(launcher: launcher, tripID: tripID))
    }
}
