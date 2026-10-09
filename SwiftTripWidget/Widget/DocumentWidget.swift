//
//  DocumentWidget.swift
//  hhWidget  (widget extension target only)
//

import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct DocumentEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDocumentSnapshot?
    let image: UIImage?
}

// MARK: - Provider

struct DocumentWidgetProvider: TimelineProvider {

    func placeholder(in context: Context) -> DocumentEntry {
        DocumentEntry(date: .now, snapshot: placeholderSnapshot, image: nil)
    }

    func getSnapshot(in context: Context,
                     completion: @escaping (DocumentEntry) -> Void) {
        let snapshot = SharedDocumentStore.shared.loadSnapshot()
        let image    = snapshot.flatMap { loadWidgetImage(from: $0.imagePath) }
        completion(DocumentEntry(date: .now, snapshot: snapshot, image: image))
    }

    func getTimeline(in context: Context,
                     completion: @escaping (Timeline<DocumentEntry>) -> Void) {
        let snapshot = SharedDocumentStore.shared.loadSnapshot()
        let image    = snapshot.flatMap { loadWidgetImage(from: $0.imagePath) }
        let entry    = DocumentEntry(date: .now, snapshot: snapshot, image: image)
        let refresh  = Calendar.current.date(byAdding: .hour, value: 1, to: .now)!
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private var placeholderSnapshot: WidgetDocumentSnapshot {
        WidgetDocumentSnapshot(
            id: "placeholder", categoryId: "", tripId: "",
            name: "Boarding Pass", categoryName: "Flight",
            notePreview: "FLIGHT: GA 123 • SEAT: 12A",
            imagePath: "", startDate: nil, endDate: nil,
            topCategories: []
        )
    }

    private func loadWidgetImage(from path: String) -> UIImage? {
        guard let url = SharedDocumentStore.shared.imageURL(for: path),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        return image.resizedForWidgetArchive(maxSide: 320, maxArea: 300_000)
    }
}

// MARK: - UIImage resize helper

private extension UIImage {
    func resizedForWidgetArchive(maxSide: CGFloat, maxArea: CGFloat) -> UIImage {
        let sideScale = min(maxSide / size.width, maxSide / size.height, 1)
        let area = size.width * size.height
        let areaScale = area > maxArea ? sqrt(maxArea / area) : 1
        let scale = min(sideScale, areaScale)

        guard scale < 1 else { return self }

        let newSize = CGSize(
            width:  max((size.width  * scale).rounded(), 1),
            height: max((size.height * scale).rounded(), 1)
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

// MARK: - Entry View

struct DocumentWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DocumentEntry

    var body: some View {
        switch family {
        case .systemSmall: SmallDocumentWidget(entry: entry)
        default:           MediumDocumentWidget(entry: entry)
        }
    }
}

// MARK: - Small Widget
//
// Photo-frame layout:
//   • Image fills the full square via scaledToFill + GeometryReader sizing
//   • Gradient scrim covers the bottom 55% — keeps top of photo clean
//   • Category pill + document name pinned to bottom-left inside the scrim
//   • No shortcut buttons

struct SmallDocumentWidget: View {
    let entry: DocumentEntry

    private var documentURL: URL {
        let s = entry.snapshot
        let catPart  = s?.categoryId.isEmpty == false ? "/\(s!.categoryId)" : ""
        let tripPart = s?.tripId.isEmpty     == false ? "/\(s!.tripId)"     : ""
        return URL(string: "hh://document/\(s?.id ?? "")\(catPart)\(tripPart)")
            ?? URL(string: "hh://")!
    }

    var body: some View {
        Link(destination: documentURL) {
            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {

                    // ── Full-square photo ──────────────────────────────────
                    if let img = entry.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    } else {
                        ZStack {
                            Color(.systemGray5)
                            Image(systemName: "doc.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }

                    // ── Bottom-half scrim ──────────────────────────────────
                    LinearGradient(
                        colors: [.black.opacity(0.78), .clear],
                        startPoint: .bottom, endPoint: .top
                    )
                    .frame(height: geo.size.height * 0.55)
                    .frame(maxWidth: .infinity, alignment: .bottom)

                    // ── Category + name labels ─────────────────────────────
                    VStack(alignment: .leading, spacing: 4) {
                        if let cat = entry.snapshot?.categoryName {
                            Text(cat.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.white.opacity(0.18)))
                        }
                        Text(entry.snapshot?.name ?? "No documents")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(10)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .containerBackground(.black, for: .widget)
    }
}

// MARK: - Medium Widget
//
// Left column : perfect square image (width == widget height via GeometryReader)
//               scaledToFill + clipped — never bleeds into the text column
// Right column: category pill, document name, note preview
// No shortcut buttons

struct MediumDocumentWidget: View {
    let entry: DocumentEntry

    private var documentURL: URL {
        let s = entry.snapshot
        let catPart  = s?.categoryId.isEmpty == false ? "/\(s!.categoryId)" : ""
        let tripPart = s?.tripId.isEmpty     == false ? "/\(s!.tripId)"     : ""
        return URL(string: "hh://document/\(s?.id ?? "")\(catPart)\(tripPart)")
            ?? URL(string: "hh://")!
    }

    var body: some View {
        GeometryReader { geo in
            // Image column width == widget height → perfect square
            let imageSize = geo.size.height

            HStack(spacing: 0) {

                // ── Square image ───────────────────────────────────────────
                Link(destination: documentURL) {
                    ZStack {
                        Color(.systemGray5)
                        if let img = entry.image {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: imageSize, height: imageSize)
                                .clipped()
                        } else {
                            Image(systemName: "doc.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(width: imageSize, height: imageSize)
                    .clipped()
                }

                // ── Text column ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 6) {

                    if let cat = entry.snapshot?.categoryName {
                        Text(cat.uppercased())
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }

                    Link(destination: documentURL) {
                        Text(entry.snapshot?.name ?? "No upcoming documents")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    if let note = entry.snapshot?.notePreview, !note.isEmpty {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

// MARK: - Widget declaration

struct DocumentWidget: Widget {
    let kind = "hhDocumentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DocumentWidgetProvider()) { entry in
            DocumentWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("hh – Next Document")
        .description("Shows your document photo, category, and key details.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

#Preview("Small", as: .systemSmall) {
    DocumentWidget()
} timeline: {
    DocumentEntry(date: .now, snapshot: WidgetDocumentSnapshot(
        id: "1", categoryId: "c1", tripId: "t1",
        name: "SQ 123 Boarding Pass", categoryName: "Flight",
        notePreview: "SEAT: 34A • GATE: B12",
        imagePath: "", startDate: nil, endDate: nil,
        topCategories: []
    ), image: nil)
}

#Preview("Medium", as: .systemMedium) {
    DocumentWidget()
} timeline: {
    DocumentEntry(date: .now, snapshot: WidgetDocumentSnapshot(
        id: "2", categoryId: "c1", tripId: "t1",
        name: "SQ 123 Boarding Pass", categoryName: "Flight",
        notePreview: "FLIGHT: SQ 123 • SEAT: 34A • GATE: B12",
        imagePath: "", startDate: nil, endDate: nil,
        topCategories: []
    ), image: nil)
}
