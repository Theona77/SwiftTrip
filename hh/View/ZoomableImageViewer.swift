//
//  ZoomableImageViewer.swift
//  hh
//
//  Full-screen document viewer:
//    • pinch to zoom (1×–5×), drag to pan while zoomed
//    • double-tap to zoom in at that point / back out
//    • swipe between pages for multi-page PDFs
//

import SwiftUI
import UIKit

// MARK: - Full-screen viewer

struct FullImageViewer: View {
    @Environment(\.dismiss) private var dismiss

    @State private var images: [UIImage]
    @State private var page: Int
    private let pdfSource: PDFSource?

    nonisolated enum PDFSource {
        case file(URL)
        case data(Data)
    }

    /// Single image.
    init(image: UIImage?) {
        self.init(images: image.map { [$0] } ?? [])
    }

    /// Several images, starting on `startIndex`.
    init(images: [UIImage], startIndex: Int = 0) {
        _images = State(initialValue: images)
        _page = State(initialValue: max(0, min(startIndex, images.count - 1)))
        pdfSource = nil
    }

    /// A scan in progress: shows the image now, all PDF pages once rendered.
    init(image: UIImage, pdfData: Data?) {
        _images = State(initialValue: [image])
        _page = State(initialValue: 0)
        pdfSource = pdfData.map { .data($0) }
    }

    /// A saved document: its PDF pages if it has a PDF, otherwise its image.
    init(document: DocumentModel, startIndex: Int = 0) {
        let image = UIImage.loadFromDocuments(named: document.imageName)
        _images = State(initialValue: image.map { [$0] } ?? [])
        _page = State(initialValue: startIndex)
        pdfSource = document.pdfFilename.map { name in
            .file(FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(URL(fileURLWithPath: name).lastPathComponent))
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if images.count > 1 {
                TabView(selection: $page) {
                    ForEach(images.indices, id: \.self) { index in
                        ZoomableImageView(image: images[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            } else if let image = images.first {
                ZoomableImageView(image: image)
                    .ignoresSafeArea()
            }

            HStack {
                if images.count > 1 {
                    Text("\(page + 1) / \(images.count)")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                Spacer()
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
                .accessibilityLabel("Close")
            }
            .padding()
        }
        .task { await loadPDFPages() }
    }

    private func loadPDFPages() async {
        guard let pdfSource else { return }
        let rendered: [UIImage] = await Task.detached(priority: .userInitiated) {
            switch pdfSource {
            case .file(let url): return UIImage.renderAllPDFPages(from: url, scale: 2)
            case .data(let data): return UIImage.renderAllPDFPages(from: data, scale: 2)
            }
        }.value
        guard !rendered.isEmpty else { return }
        images = rendered
        page = min(page, rendered.count - 1)
    }
}

// MARK: - Zoomable image (UIScrollView)

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    var maximumZoom: CGFloat = 5

    func makeUIView(context: Context) -> ZoomingScrollView {
        ZoomingScrollView(image: image, maximumZoom: maximumZoom)
    }

    func updateUIView(_ view: ZoomingScrollView, context: Context) {
        view.setImage(image)
    }
}

final class ZoomingScrollView: UIScrollView, UIScrollViewDelegate {

    private let imageView = UIImageView()
    private var lastBoundsSize: CGSize = .zero

    init(image: UIImage, maximumZoom: CGFloat) {
        super.init(frame: .zero)
        delegate = self
        minimumZoomScale = 1
        maximumZoomScale = maximumZoom
        bouncesZoom = true
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        decelerationRate = .fast
        backgroundColor = .clear

        imageView.contentMode = .scaleAspectFit
        imageView.image = image
        imageView.isAccessibilityElement = true
        imageView.accessibilityLabel = "Document image"
        addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setImage(_ image: UIImage) {
        guard imageView.image !== image else { return }
        imageView.image = image
        resetLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // layoutSubviews runs on every scroll — only refit when the size changes.
        if bounds.size != lastBoundsSize {
            lastBoundsSize = bounds.size
            resetLayout()
        }
    }

    /// Fits the image inside the bounds at 1× and centres it.
    private func resetLayout() {
        guard let image = imageView.image, bounds.width > 0, bounds.height > 0,
              image.size.width > 0, image.size.height > 0 else { return }
        zoomScale = minimumZoomScale
        let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = CGSize(width: image.size.width * fit, height: image.size.height * fit)
        imageView.frame = CGRect(origin: .zero, size: size)
        contentSize = size
        centerContent()
    }

    private func centerContent() {
        let x = max((bounds.width  - contentSize.width)  / 2, 0)
        let y = max((bounds.height - contentSize.height) / 2, 0)
        contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    // MARK: UIScrollViewDelegate

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerContent() }

    // MARK: Double tap

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale {
            setZoomScale(minimumZoomScale, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let scale = min(maximumZoomScale, 2.5)
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                            width: size.width, height: size.height),
                 animated: true)
        }
    }
}

// MARK: - Tap-to-zoom preview

/// Inline preview that opens the full-screen zoomable viewer when tapped.
/// Used on the scan confirmation and details screens.
struct TapToZoomImage: View {
    let image: UIImage
    var pdfData: Data? = nil
    var cornerRadius: CGFloat = 12

    @State private var showViewer = false

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(alignment: .bottomTrailing) {
                HStack(spacing: 4) {
                    if pdfData != nil {
                        Text("PDF").font(.caption2.bold())
                    }
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .padding(8)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(10)
            }
            .contentShape(Rectangle())
            .onTapGesture { showViewer = true }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(pdfData != nil ? "PDF document preview" : "Document preview")
            .accessibilityHint("Opens full screen with zoom")
            .fullScreenCover(isPresented: $showViewer) {
                FullImageViewer(image: image, pdfData: pdfData)
            }
    }
}
