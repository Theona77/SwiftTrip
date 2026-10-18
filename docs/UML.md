# SwiftTrip UML Diagrams

UML views of SwiftTrip, drawn from the current code. For product-level diagrams (use cases, goals and strategy, UI navigation, user journey), see [PRODUCT.md](PRODUCT.md). For the narrative architecture, see [ARCHITECTURE.md](ARCHITECTURE.md).

| Diagram | Shows |
|---|---|
| [1. Class diagram: domain, state and widget](#1-class-diagram-domain-state-and-widget) | Data model, `HomeViewModel`, deep links, widget extension |
| [2. Class diagram: scan pipeline](#2-class-diagram-scan-pipeline) | Capture, OCR, MRZ, classification, Foundation Models assist |
| [3. Sequence diagram: scanning a document](#3-sequence-diagram-scanning-a-document) | What happens from picking a photo or PDF to the widget update |

Each diagram is available as a PNG in [`docs/uml/`](uml/) and as Mermaid source (`.mmd`). GitHub draws the Mermaid blocks below directly, and you can edit them at [mermaid.live](https://mermaid.live).

### Notation

| Symbol | Meaning |
|---|---|
| `+` / `-` | public / private member |
| underlined or `$` | static member |
| `«struct»`, `«enumeration»`, `«ObservableObject»`… | stereotype: the Swift kind or protocol |
| ◆── (filled diamond) | **composition**: the owner creates and owns the part (`TripModel` → `CategoryModel`) |
| ◇── (hollow diamond) | **aggregation**: holds a collection (`HomeViewModel` → trips) |
| ──▶ (solid arrow) | **association**: holds a reference / returns |
| ┈┈▶ (dashed arrow) | **dependency**: calls or uses |
| `1`, `*`, `0..10` | multiplicity |

Swift arrays are written `List~T~`, and optionals keep Swift's `?`.

---

## 1. Class diagram: domain, state and widget

![Class diagram: domain, state and widget](uml/class-domain.png)

**How to read it**
- `hhApp` owns the two long-lived objects: `HomeViewModel` (all app data) and `DeepLinkHandler`.
- The data is a tree: **`TripModel` ◆ `CategoryModel` ◆ `DocumentModel`**. Personal Essentials are `CategoryModel`s held directly by the view model (`globalCategories`). `recentDocuments` keeps up to 10 references.
- `HomeViewModel.refreshWidget()` calls **`SharedDocumentStore`**. It is compiled into both the app and the widget, and it writes a `WidgetDocumentSnapshot` to the App Group. The widget's `DocumentWidgetProvider` reads it back into a `DocumentEntry`.
- A widget tap opens `hh://document/…`. `DeepLinkHandler` turns it into a `DeepLinkDestination`, and `RootView` pushes the matching `AppDestination`.

<details><summary>Mermaid source</summary>

```mermaid
classDiagram
direction TB

class hhApp {
  <<App>>
  -homeViewModel: HomeViewModel
  -deepLinkHandler: DeepLinkHandler
  +body: Scene
}

class RootView {
  <<View>>
  -hasOnboarded: Bool
  -navigationPath: NavigationPath
  -handleDeepLink(DeepLinkDestination)
}

class AppDestination {
  <<enumeration>>
  category(CategoryModel, TripModel)
  document(DocumentModel, CategoryModel, TripModel)
  anyDocument(DocumentModel)
}

class HomeViewModel {
  <<ObservableObject>>
  +trips: List~TripModel~
  +globalCategories: List~CategoryModel~
  +recentDocuments: List~DocumentModel~
  +personalDocuments: List~DocumentModel~
  +searchText: String
  +sortedTrips: List~TripModel~
  +filteredDocuments: List~DocumentModel~
  +addTrip(TripModel)
  +removeTrip(TripModel)
  +updateTripDates(TripModel, Date, Date)
  +addCategory(CategoryModel, TripModel)
  +removeCategory(CategoryModel, TripModel)
  +addDocument(DocumentModel, CategoryModel, TripModel)
  +updateDocument(DocumentModel, CategoryModel, TripModel)
  +deleteDocument(DocumentModel)
  +addPersonalDocumentToGlobalCategory(DocumentModel, DocumentCategory)
  +recordRecentDocument(DocumentModel)
  +refreshWidget()
  +flushPendingWork()
  -persistAppState()
}

class TripModel {
  <<struct, Codable>>
  +id: UUID
  +name: String
  +startDate: Date
  +endDate: Date
  +description: String
  +imageName: String
  +isSaved: Bool
  +categories: List~CategoryModel~
  +isUpcoming: Bool
  +isOngoing: Bool
  +isCompleted: Bool
  +makeNew(name, startDate, endDate)$ TripModel
}

class CategoryModel {
  <<struct, Codable>>
  +id: UUID
  +name: String
  +icon: String
  +documents: List~DocumentModel~
  +defaultCategories: List~CategoryModel~$
}

class DocumentModel {
  <<struct, Codable>>
  +id: UUID
  +name: String
  +imageName: String
  +note: String
  +startDate: Date?
  +endDate: Date?
  +categoryName: String
  +pdfFilename: String?
}

class DeepLinkHandler {
  <<ObservableObject, singleton>>
  +pendingDestination: DeepLinkDestination?
  +handle(url: URL)
}

class DeepLinkDestination {
  <<enumeration>>
  document(id, categoryId, tripId)
  category(id, tripId)
}

class SharedDocumentStore {
  <<singleton, app + widget>>
  -appGroupID: String
  +updateWidgetSnapshot(trips, globalCategories, recentDocuments)
  +loadSnapshot() WidgetDocumentSnapshot?
  -pickNextDocument() DocumentModel?
  -copyImageToSharedContainer(path, id) String?
}

class WidgetDocumentSnapshot {
  <<struct, Codable>>
  +id: String
  +categoryId: String
  +tripId: String
  +name: String
  +categoryName: String
  +notePreview: String
  +imagePath: String
  +startDate: Date?
  +endDate: Date?
}

class DocumentWidgetProvider {
  <<TimelineProvider>>
  +placeholder() DocumentEntry
  +getSnapshot() DocumentEntry
  +getTimeline() Timeline
}

class DocumentEntry {
  <<TimelineEntry>>
  +date: Date
  +snapshot: WidgetDocumentSnapshot?
  +image: UIImage?
}

hhApp *-- HomeViewModel : owns
hhApp *-- DeepLinkHandler : owns
hhApp --> RootView : shows
RootView ..> HomeViewModel : observes
RootView ..> DeepLinkHandler : observes
RootView --> AppDestination : pushes
DeepLinkHandler --> DeepLinkDestination
HomeViewModel "1" o-- "*" TripModel : trips
HomeViewModel "1" o-- "*" CategoryModel : globalCategories
HomeViewModel "1" o-- "0..10" DocumentModel : recentDocuments
TripModel "1" *-- "*" CategoryModel
CategoryModel "1" *-- "*" DocumentModel
HomeViewModel ..> SharedDocumentStore : refreshWidget()
SharedDocumentStore ..> WidgetDocumentSnapshot : writes / reads
DocumentWidgetProvider ..> SharedDocumentStore : loadSnapshot()
DocumentWidgetProvider --> DocumentEntry : creates
DocumentEntry --> WidgetDocumentSnapshot
```
</details>

---

## 2. Class diagram: scan pipeline

![Class diagram: scan pipeline](uml/class-scan.png)

**How to read it**
- `ScanFlowLauncher` turns the user's pick into `ScanInput`s and presents `ScanFlowCoordinator`, which **owns** a `ScanStore`.
- `ScanStore` holds the batch of `ScannedDocument`s. For each one it calls:
  - **`VisionOCRService`** (with **`MRZParser`**), which produces `ExtractedDocumentData`
  - **`DocumentClassifier`**, which may consult the optional Core ML **`DocumentTextClassifier`**
  - **`DocumentAIAssistant`** (Foundation Models), only when the result is unsure
- Both classifiers return a **`DocumentClassification`**: a `DocumentCategory`, a confidence, and the source of the answer.
- `DocumentDetailsScreen` saves the confirmed document through `HomeViewModel`. In DEBUG builds it also logs a training sample with `TrainingSampleRecorder`.

<details><summary>Mermaid source</summary>

```mermaid
classDiagram
direction TB

class ScanFlowLauncher {
  <<ObservableObject>>
  +showScanFlow: Bool
  +show(source: Source)
  +launch(inputs: List~ScanInput~)
  +loadAndLaunch(items) async
  +handleFileImport(Result)
}

class ScanFlowCoordinator {
  <<View>>
  +source: Source
  +tripID: UUID?
  +initialInputs: List~ScanInput~
  -store: ScanStore
}

class ScanInput {
  <<struct>>
  +image: UIImage
  +pdfData: Data?
  +pdfText: String?
  +pagesForOCR: List~UIImage~
  +isPDF: Bool
  +load(from: URL)$ ScanInput?
  +fromPDF(data: Data)$ ScanInput?
}

class ScanStore {
  <<ObservableObject>>
  +scannedDocs: List~ScannedDocument~
  +currentIndex: Int
  +currentDoc: ScannedDocument?
  +addInputs(List~ScanInput~)
  +replaceInput(ScanInput, Int)
  +setCategory(DocumentCategory, Int)
  +remove(at: Int)
  -runOCR(on: ScanInput, for: Int)
  -apply(data, result, runID, finished)
}

class ScannedDocument {
  <<struct>>
  +id: UUID
  +image: UIImage
  +pdfData: Data?
  +ocrData: ExtractedDocumentData
  +category: DocumentCategory
  +predictedCategory: DocumentCategory
  +categoryConfidence: Double
  +isProcessing: Bool
  +ocrRunID: UUID
}

class VisionOCRService {
  <<singleton>>
  +recognise(image, completion)
  +recognise(pages, completion)
  +extract(fromText: String) ExtractedDocumentData
  +parse(lines, raw) ExtractedDocumentData
}

class MRZParser {
  <<enum, static>>
  +parse(lines: List~String~)$ MRZResult?
}

class MRZResult {
  <<struct>>
  +kind: Kind
  +surname: String
  +givenNames: String
  +documentNumber: String
  +nationality: String
  +dateOfBirth: String?
  +expiryDate: String?
  +isValid: Bool
}

class ExtractedDocumentData {
  <<struct>>
  +rawText: String
  +mrz: MRZResult?
  +fullName: String?
  +documentNumber: String?
  +nik: String?
  +bookingCode: String?
  +pnr: String?
  +flightNumber: String?
  +seatNumber: String?
  +origin / destination: String?
  +date / time: String?
  +hotelName: String?
  +extractedFields: List~Field~
}

class DocumentClassifier {
  <<singleton>>
  +confidentThreshold: Double = 0.6$
  +classifyWithConfidence(data) DocumentClassification
  -keywordScore(text, data) DocumentClassification
}

class DocumentTextClassifier {
  <<singleton, Core ML>>
  -model: NLModel?
  +isAvailable: Bool
  +predict(rawText) Prediction?
  +normalise(raw)$ String
}

class DocumentAIAssistant {
  <<singleton, Foundation Models>>
  -timeout: Double = 10
  +isAvailable: Bool
  +shouldAssist(data, rules) Bool
  +refine(data, rules) async RefinedResult
  -analyse(rawText) async GeneratedDocumentAnalysis?
  -merge(analysis, data, rules) RefinedResult
}

class DocumentClassification {
  <<struct>>
  +category: DocumentCategory
  +confidence: Double
  +source: Source
}

class DocumentCategory {
  <<enumeration>>
  nationalID
  passport
  visa
  boardingPass
  hotel
  train
  reservation
  activity
  event
  other
  +trainingLabel: String
  +tripCategoryName: String?
}

class TrainingSampleRecorder {
  <<singleton, DEBUG only>>
  +isEnabled: Bool
  +record(text, confirmed, predicted)
}

class DocumentDetailsScreen {
  <<View>>
  +store: ScanStore
  +tripID: UUID?
}

class HomeViewModel {
  <<ObservableObject>>
}

ScanFlowLauncher ..> ScanInput : creates
ScanFlowLauncher --> ScanFlowCoordinator : presents
ScanFlowCoordinator *-- ScanStore : owns
ScanStore "1" *-- "*" ScannedDocument
ScanStore ..> ScanInput : consumes
ScanStore ..> VisionOCRService : OCR
ScanStore ..> DocumentClassifier : rules
ScanStore ..> DocumentAIAssistant : refine (async)
VisionOCRService ..> MRZParser
VisionOCRService --> ExtractedDocumentData : produces
ExtractedDocumentData --> MRZResult
ScannedDocument --> ExtractedDocumentData
ScannedDocument --> DocumentCategory
DocumentClassifier ..> DocumentTextClassifier : optional model
DocumentClassifier --> DocumentClassification : returns
DocumentAIAssistant --> DocumentClassification : returns
DocumentClassification --> DocumentCategory
DocumentDetailsScreen ..> ScanStore : observes
DocumentDetailsScreen ..> HomeViewModel : save
DocumentDetailsScreen ..> TrainingSampleRecorder : record
```
</details>

---

## 3. Sequence diagram: scanning a document

![Sequence diagram: scanning a document](uml/sequence-scan.png)

**How to read it**
- **Steps 3–5:** a digital PDF is read from its text layer. A photo or scanned PDF goes through Vision OCR and MRZ parsing.
- **Steps 7–9:** the rule-based result is shown **immediately**.
- **Steps 10–12 (optional):** Foundation Models refines the result in the background, only when the rules are unsure, returned "Others", or are missing key fields.
- **Steps 13–17:** saving updates `HomeViewModel`, which writes JSON after 300 ms and refreshes the widget after 500 ms.

<details><summary>Mermaid source</summary>

```mermaid
sequenceDiagram
autonumber
actor U as User
participant L as ScanFlowLauncher
participant S as ScanStore
participant O as VisionOCRService
participant C as DocumentClassifier
participant A as DocumentAIAssistant
participant D as DocumentDetailsScreen
participant VM as HomeViewModel
participant W as SharedDocumentStore

U->>L: Pick camera / photo / PDF
L->>S: addInputs([ScanInput])
alt digital PDF with text layer
  S->>O: extract(fromText:)
else photo or scanned PDF
  S->>O: recognise(image / pages)
  O->>O: Vision OCR + MRZParser
end
O-->>S: ExtractedDocumentData
S->>C: classifyWithConfidence(data)
C-->>S: DocumentClassification
S-->>U: show category + fields (instant)
opt unsure, "Others" or key fields missing
  S->>A: refine(data, rules) async
  A-->>S: gaps filled / category refined
  S-->>U: update screen
end
U->>D: review, edit, choose trip
D->>VM: addDocument / addPersonalDocumentToGlobalCategory
VM->>VM: persist JSON (debounced 300 ms)
VM->>W: refreshWidget (debounced 500 ms)
W-->>U: widget shows next document
```
</details>

---

## Updating the diagrams

1. Edit the `.mmd` file in `docs/uml/` and the matching block above.
2. Re-export the PNG:
   - **Quickest:** paste the source into [mermaid.live](https://mermaid.live) and choose **Actions ▸ PNG**.
   - **Command line:** `npx -p @mermaid-js/mermaid-cli mmdc -i docs/uml/class-scan.mmd -o docs/uml/class-scan.png -s 2 -b white`
