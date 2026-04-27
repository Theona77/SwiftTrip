//
//  DocumentWidget.swift
//  hhWidget
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
            topCategories: previewShortcuts
        )
    }

    private func loadWidgetImage(from path: String) -> UIImage? {
        guard let image = UIImage(contentsOfFile: path) else { return nil }
        return image.resizedForWidgetArchive(maxSide: 320, maxArea: 300_000)
    }
}

private let previewShortcuts: [WidgetCategoryShortcut] = [
    WidgetCategoryShortcut(id: "1", tripId: "", name: "Flight",      icon: "airplane",        colorHex: "#5B8CFF"),
    WidgetCategoryShortcut(id: "2", tripId: "", name: "Hotel",       icon: "bed.double.fill", colorHex: "#FF9F5B"),
    WidgetCategoryShortcut(id: "3", tripId: "", name: "Reservation", icon: "fork.knife",      colorHex: "#5BCC8C"),
]

// MARK: - Color helper

private func colorFromHex(_ hex: String) -> Color {
    let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: h).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xFF) / 255
    let g = Double((int >> 8)  & 0xFF) / 255
    let b = Double( int        & 0xFF) / 255
    return Color(red: r, green: g, blue: b)
}

private extension UIImage {
    func resizedForWidgetArchive(maxSide: CGFloat, maxArea: CGFloat) -> UIImage {
        let sideScale = min(maxSide / size.width, maxSide / size.height, 1)
        let area = size.width * size.height
        let areaScale = area > maxArea ? sqrt(maxArea / area) : 1
        let scale = min(sideScale, areaScale)

        guard scale < 1 else { return self }

        let newSize = CGSize(
            width: max((size.width * scale).rounded(), 1),
            height: max((size.height * scale).rounded(), 1)
        )

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
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

// MARK: - Shortcut Button

struct CategoryShortcutButton: View {
    let shortcut: WidgetCategoryShortcut

    // hh://category/{categoryId}/{tripId}
    var deepLinkURL: URL {
        let tripPart = shortcut.tripId.isEmpty ? "" : "/\(shortcut.tripId)"
        return URL(string: "hh://category/\(shortcut.id)\(tripPart)") ?? URL(string: "hh://")!
    }

    var body: some View {
        Link(destination: deepLinkURL) {
            ZStack {
                Circle()
                    .fill(colorFromHex(shortcut.colorHex).opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: shortcut.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(colorFromHex(shortcut.colorHex))
            }
        }
    }
}

// MARK: - Small Widget

struct SmallDocumentWidget: View {
    let entry: DocumentEntry

    // hh://document/{docId}/{categoryId}/{tripId}
    private var documentURL: URL {
        let s = entry.snapshot
        let catPart  = s?.categoryId.isEmpty == false ? "/\(s!.categoryId)" : ""
        let tripPart = s?.tripId.isEmpty     == false ? "/\(s!.tripId)"     : ""
        return URL(string: "hh://document/\(s?.id ?? "")\(catPart)\(tripPart)") ?? URL(string: "hh://")!
    }

    var body: some View {
        ZStack {
            Link(destination: documentURL) {
                ZStack(alignment: .bottomLeading) {
                    if let img = entry.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Color(.systemGray5)
                        Image(systemName: "doc.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }

                    LinearGradient(
                        colors: [.black.opacity(0.7), .clear],
                        startPoint: .bottom, endPoint: .center
                    )

                    VStack(alignment: .leading, spacing: 3) {
                        if let cat = entry.snapshot?.categoryName {
                            Text(cat.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.white.opacity(0.2)))
                        }
                        Text(entry.snapshot?.name ?? "No documents")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .lineLimit(2)
                    }
                    .padding(10)
                }
            }

            if let shortcuts = entry.snapshot?.topCategories, !shortcuts.isEmpty {
                VStack(spacing: 6) {
                    ForEach(shortcuts.prefix(3)) { shortcut in
                        CategoryShortcutButton(shortcut: shortcut)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 8)
            }
        }
        .containerBackground(.clear, for: .widget)
    }
}

// MARK: - Medium Widget

struct MediumDocumentWidget: View {
    let entry: DocumentEntry

    private var documentURL: URL {
        let s = entry.snapshot
        let catPart  = s?.categoryId.isEmpty == false ? "/\(s!.categoryId)" : ""
        let tripPart = s?.tripId.isEmpty     == false ? "/\(s!.tripId)"     : ""
        return URL(string: "hh://document/\(s?.id ?? "")\(catPart)\(tripPart)") ?? URL(string: "hh://")!
    }

    var body: some View {
        HStack(spacing: 0) {

            Link(destination: documentURL) {
                ZStack {
                    Color(.systemGray5)
                    if let img = entry.image {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 120)
                .clipped()
            }

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
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                if let shortcuts = entry.snapshot?.topCategories, !shortcuts.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(shortcuts.prefix(3)) { shortcut in
                            CategoryShortcutButton(shortcut: shortcut)
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }
}

// MARK: - Widget

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
        topCategories: previewShortcuts
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
        topCategories: previewShortcuts
    ), image: nil)
}
