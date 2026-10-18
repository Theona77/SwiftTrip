//
//  ScanFlowCoordinator.swift
//  hh


import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

enum ScanNavDestination: Hashable { case details }

struct ScanFlowCoordinator: View {

    enum Source { case camera, photos, files }

    let source: Source
    var tripID: UUID? = nil
    var categoryName: String? = nil
    var initialInputs: [ScanInput] = []
    var launchSourceOnAppear = true

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vm: HomeViewModel
    @StateObject private var store = ScanStore()

    @State private var path: [ScanNavDestination] = []
    @State private var showCameraReplace  = false
    @State private var showPhotosReplace  = false
    @State private var replacePhotoItems: [PhotosPickerItem] = []
    @State private var initialPhotoItems: [PhotosPickerItem] = []
    @State private var showInitialCamera  = false
    @State private var showInitialFiles   = false
    @State private var showInitialPhotos  = false
    @State private var didBootstrap       = false

    var body: some View {
        NavigationStack(path: $path) {
            confirmView
                .navigationDestination(for: ScanNavDestination.self) { _ in
                    DocumentDetailsScreen(
                        store: store,
                        tripID: tripID,
                        categoryName: categoryName,
                        onBack: { path.removeLast() },
                        onDidSave: { dismiss() }
                    )
                    .environmentObject(vm)
                }
        }
        .onAppear { bootstrapFlowIfNeeded() }
        // Retake / replace pickers
        .fullScreenCover(isPresented: $showCameraReplace) {
            CameraPickerView { img in store.replaceImage(img, at: store.currentIndex) }
        }
        .photosPicker(isPresented: $showPhotosReplace,
                      selection: $replacePhotoItems,
                      maxSelectionCount: 10, matching: .images)
        .onChange(of: replacePhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadAndAdd(items, replacing: true) }
        }
        // Initial source pickers
        .fullScreenCover(isPresented: $showInitialCamera) {
            CameraPickerView { img in store.addImages([img]) }
        }
        .photosPicker(isPresented: $showInitialPhotos,
                      selection: $initialPhotoItems,
                      maxSelectionCount: 10, matching: .images)
        .onChange(of: initialPhotoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await loadAndAdd(items, replacing: false) }
        }
        .fileImporter(isPresented: $showInitialFiles,
                      allowedContentTypes: [.image, .pdf],
                      allowsMultipleSelection: true) { result in
            handleFileImport(result)
        }
    }

    // MARK: - Confirm view (root of NavigationStack)

    @ViewBuilder
    private var confirmView: some View {
        if store.scannedDocs.isEmpty {
            // Invisible placeholder while pickers / camera are opening
            Color.clear.ignoresSafeArea()
        } else {
            ConfirmScanScreen(
                store: store,
                onSaveCurrent: { _ in
                    path.append(.details)   // push DocumentDetailsScreen
                },
                onDiscard: {
                    store.remove(at: store.currentIndex)
                    if store.scannedDocs.isEmpty { dismiss() }
                },
                onRetake: { triggerRetake() }
            )
        }
    }

    // MARK: - Bootstrap

    private func bootstrapFlowIfNeeded() {
        guard !didBootstrap else { return }
        didBootstrap = true

        if !initialInputs.isEmpty {
            store.addInputs(initialInputs)
        } else if launchSourceOnAppear {
            openInitialSource()
        }
    }

    // MARK: - Source helpers

    private func openInitialSource() {
        switch source {
        case .camera: showInitialCamera = true
        case .photos: showInitialPhotos = true
        case .files:  showInitialFiles  = true
        }
    }

    private func triggerRetake() {
        switch source {
        case .camera: showCameraReplace = true
        case .photos: showPhotosReplace = true
        case .files:  showInitialFiles  = true
        }
    }

    // MARK: - Image loading

    @MainActor
    private func loadAndAdd(_ items: [PhotosPickerItem], replacing: Bool) async {
        var loaded: [UIImage] = []
        await withTaskGroup(of: UIImage?.self) { group in
            for item in items {
                group.addTask {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let img = UIImage(data: data) else { return nil }
                    return await img.downsampledForOCR()
                }
            }
            for await result in group { if let img = result { loaded.append(img) } }
        }
        guard !loaded.isEmpty else { return }
        if replacing {
            loaded.count == 1
                ? store.replaceImage(loaded[0], at: store.currentIndex)
                : store.addImages(loaded)
            replacePhotoItems = []
        } else {
            store.addImages(loaded)
            initialPhotoItems = []
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        let inputs = urls.compactMap { url -> ScanInput? in
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }
            return ScanInput.load(from: url)
        }
        store.addInputs(inputs)
    }
}

// MARK: - UIImage downsampling

extension UIImage {
    func downsampledForOCR(maxDimension: CGFloat = 1500) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - CameraPickerView

struct CameraPickerView: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let capturedImage = (info[.originalImage] as? UIImage)?.downsampledForOCR()
            parent.dismiss()
            if let capturedImage {
                DispatchQueue.main.async {
                    self.parent.onCapture(capturedImage)
                }
            }
        }
    }
}
