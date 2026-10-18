# SwiftTrip Development Guide

How to build, run, debug and extend SwiftTrip. For the design itself, see [ARCHITECTURE.md](ARCHITECTURE.md).

---

## Targets and key settings

| | App | Widget extension |
|---|---|---|
| Target / scheme | `SwiftTrip` | `SwiftTripWidgetExtension` |
| Bundle ID | `com.theona.swifttrip` | `com.theona.swifttrip.widget` |
| Deployment target | iOS 26.0 | iOS 18.6 |
| Devices | iPhone only (`TARGETED_DEVICE_FAMILY = 1`) | iPhone only |
| App Group | `group.com.hh.documents` | `group.com.hh.documents` |
| Entitlements | `SwiftTrip/SwiftTrip.entitlements` | `SwiftTripWidgetExtension.entitlements` |
| Privacy manifest | `SwiftTrip/PrivacyInfo.xcprivacy` | `SwiftTripWidget/PrivacyInfo.xcprivacy` |
| Swift | Swift 5 mode, `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, approachable concurrency | approachable concurrency |
| URL scheme | `hh` | — |

**Folders are synchronised groups** (Xcode 16+). Files added under `SwiftTrip/` or `SwiftTripWidget/` join their target automatically, with no `.pbxproj` edits. The exceptions are `SwiftTripWidget/Widget/DocumentWidget.swift` and `SharedDocumentStore.swift`, which are also compiled into the app.

There are **no package dependencies**.

---

## Build and run

1. Open `SwiftTrip.xcodeproj` in **Xcode 26+**.
2. **Signing & Capabilities:** set your team for both targets. If you use your own bundle IDs:
   - Create a matching App Group, or rename `group.com.hh.documents`, in **both** targets.
   - If you rename the group, also update `appGroupID` in `SwiftTripWidget/Widget/SharedDocumentStore.swift`.
3. Choose the **SwiftTrip** scheme and run (**⌘R**).

From the command line:

```bash
xcodebuild -project SwiftTrip.xcodeproj -scheme SwiftTrip \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### First launch
- `BoardingScreen` appears until `hasOnboarded` is set.
- With no saved data, two sample trips (**Japan**, **Korea**) and empty Personal Essentials categories are created.

To start fresh, delete the app from the simulator or device. For onboarding only, delete the `hasOnboarded` user default.

### Simulator vs device
| Feature | Simulator | Device |
|---|---|---|
| Camera scan | ❌ (import from Photos / Files instead) | ✅ |
| Vision OCR, MRZ, PDF import | ✅ | ✅ |
| Foundation Models second opinion | Only if the Mac supports Apple Intelligence and it's enabled | iPhone with Apple Intelligence |
| Widget | ✅ | ✅ |

Drag test images or PDFs onto the simulator to add them to Photos or Files.

---

## Where the data lives (for debugging)

| Data | Path in the app container |
|---|---|
| App state | `Library/Application Support/HomeState/home_state.json` |
| Document images / PDFs | `Documents/*.jpg`, `Documents/*.pdf` |
| Classifier samples (DEBUG) | `Documents/ClassifierTraining/samples.json` |
| Widget snapshot | App Group container, `UserDefaults` suite `group.com.hh.documents`, key `widget_next_document` |

- **Simulator:** `xcrun simctl get_app_container booted com.theona.swifttrip data`
- **Device:** Xcode → **Window ▸ Devices and Simulators** → SwiftTrip → **Download Container…**

---

## Testing deep links and the widget

```bash
# Open a document (IDs come from home_state.json)
xcrun simctl openurl booted "hh://document/<docId>/<categoryId>/<tripId>"

# Personal Essentials document (empty trip ID)
xcrun simctl openurl booted "hh://document/<docId>/<categoryId>/"

# Open a category
xcrun simctl openurl booted "hh://category/<categoryId>/<tripId>"
```

To test the widget:
1. Run the `SwiftTripWidgetExtension` scheme, or long-press the Home Screen → **+** → SwiftTrip.
2. Give a document a **start date within 2 days**. The widget should switch to it on the next refresh.
3. App changes trigger `WidgetCenter.reloadAllTimelines()` about 500 ms after the edit.

---

## Working on the scan pipeline

| Task | File |
|---|---|
| Add or fix a field the parser extracts | `Service/VisionOCRService.swift`: `parse(lines:raw:)` and `ExtractedDocumentData` |
| Passport / visa / ID machine-readable zone | `Service/MRZParser.swift` |
| Classification rules or keywords | `Service/DocumentClassifier.swift`: steps 2 and 4, the `keywords` table, `minimumScore` |
| When the Foundation Models step runs, and what it may fill | `Service/DocumentAIAssistant.swift`: `shouldAssist`, `missingKeyFields`, `merge` |
| PDF handling (text layer vs OCR, page limits) | `Models/ScanInput.swift` |
| Review / save UI | `Screen/ConfirmationDocsScreen/` |

**Adding a new document category:**
1. Add a case to `DocumentCategory` in `DocumentClassifier.swift`, with its icon, colour, `trainingLabel` and `tripCategoryName`.
2. Add keywords for it.
3. Add the label to `GeneratedDocumentAnalysis.category` in `DocumentAIAssistant.swift`.
4. Retrain the Create ML model, if you ship one.

### Create ML model (optional)
See [Tools/DocumentClassifierTraining/README.md](../Tools/DocumentClassifierTraining/README.md). In short:
1. Debug builds record samples.
2. Train with `swift train.swift samples.json --out DocumentTypeClassifier.mlmodel`.
3. Drop the model into `SwiftTrip/`.

`DocumentTextClassifier.normalise` and the training script must stay identical.

> Sample files contain personal data from real documents. `Tools/DocumentClassifierTraining/samples*.json` is git-ignored; keep it that way.

---

## Conventions

- **State changes go through `HomeViewModel`.** Views don't mutate models directly.
- **Store files, not blobs.** Models keep file names. Use the `UIImage` storage helpers in `Extension/UIImage+LocalStorage.swift`.
- **Downsample images** before OCR (`downsampledForOCR()`) and for thumbnails. Full camera photos are about 48 MB decoded.
- **Never add network calls, analytics or SDKs** without updating `docs/AppStoreSubmission.md`, `docs/privacy-policy.md` and both privacy manifests. The "Data Not Collected" label depends on this.
- **Accessibility:** give icon-only buttons an `accessibilityLabel`, use Dynamic Type text styles, and use system colours. See `docs/AppStoreSubmission.md` for the accessibility claims.

---

## Release checklist

1. Bump `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in **both** targets.
2. Product ▸ Archive → Distribute → App Store Connect.
3. Check App Privacy and Accessibility answers against [AppStoreSubmission.md](AppStoreSubmission.md).
4. Update App Review notes if features changed. See [AppReview/Guideline-2.1-Response.md](../AppReview/Guideline-2.1-Response.md).
5. Screenshots: 6.9" iPhone only, showing real app screens.

---

## Known cleanup / tech debt

| Item | Notes |
|---|---|
| `hh/PrivacyInfo.xcprivacy` at the repo root | Leftover from before the rename. It isn't in any target and can be deleted. |
| `SwiftTrip/.swift` | Empty file. It can be deleted. |
| "hh" names | `hhApp`, file headers, the `hh://` scheme and the `group.com.hh.documents` App Group still use the old project name. **Don't rename the App Group or URL scheme after release:** existing widget data and links would break. |
| No unit tests | `MRZParser`, `DocumentClassifier` and `VisionOCRService.parse` are pure logic and easy to cover. |
| Widget deployment target 18.6 vs app 26.0 | Harmless, but could be aligned. |
