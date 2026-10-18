# App Review – Guideline 2.1 Information Needed (SwiftTrip 1.0)

Paste the section below into the App Store Connect reply **and** into
App Review Information → Notes. Attach the screen recording to the reply.

---

Hello App Review Team,

Thank you for reviewing SwiftTrip. Please find the requested information below.

**1. Screen recording**
Attached is a screen recording captured on a physical iPhone running the latest iOS. It starts from app launch and shows onboarding, creating a trip, scanning a travel document with the camera, importing from Photos and from a PDF file, reviewing the automatically extracted details, saving the document, viewing and editing it, deleting it, and the Home Screen widget.

SwiftTrip has no account registration or login, no user-generated content that is shared with or visible to other users, and no paid content or In-App Purchases, so those flows are not applicable.

**2. Purpose and target audience**
SwiftTrip is a personal travel-document organiser for travellers, from holidaymakers to frequent business travellers. When travelling, people's documents are scattered across email, screenshots, PDFs and paper: passports, visas, boarding passes, hotel and train bookings, and event tickets. Finding the right one at a check-in counter or gate is stressful, especially without a connection.

SwiftTrip lets the user capture or import these documents once and organise them by trip. It reads each document on-device to suggest a category (e.g. Passport, Boarding Pass, Hotel) and pull out key details (name, booking code, flight number, seat, date), so everything is available instantly and offline. A Home Screen widget shows the next relevant document so it can be opened in one tap.

**3. Setup and access instructions**
No login, credentials, or sample files are required. All features are available immediately after install.
1. Launch the app and tap "Next" → "Get Started" on the onboarding screens.
2. On Home, tap "Add Trip", enter a name and dates, and tap "Create".
3. Tap the scan/add button at the bottom and choose "Take Picture", "Photos / Gallery" or "Files" (PDF supported). Any boarding pass, hotel confirmation, ticket, or ID-style document can be used to test.
4. Review the identified category and extracted information, choose the trip (or "Personal Essentials" for passport/ID/visa), and save.
5. Open the trip → a category → a document to view, edit information, or delete it. Long-press thumbnails in a category to multi-select and delete.
6. Optionally add the "SwiftTrip" widget from the Home Screen widget gallery; tapping it opens the document directly.

Camera permission is requested only when the user chooses to take a picture.

**4. External services, tools, or platforms**
SwiftTrip does not use any external servers, third-party SDKs, analytics, advertising, authentication, payment, or AI services. Core functionality relies only on Apple system frameworks running on the device:
- Vision (on-device text recognition)
- UIImagePickerController and PhotosUI (camera and photo selection)
- PDFKit (PDF import and rendering)
- WidgetKit with an App Group (to show documents in the Home Screen widget)

All documents and data are stored locally on the device and are never uploaded to the developer or to any third party.

**5. Regional differences**
The app functions consistently across all regions. There are no region-specific features or content. The interface is in English; text recognition works on documents printed in Latin script.

**6. Regulated industry / third-party material**
SwiftTrip does not operate in a regulated industry and does not provide travel booking, identity verification, or government services. It only stores documents that the user already owns, for their own personal reference. The app does not include protected third-party material; all images bundled in the app are owned by or licensed to the developer.

Thank you,
Theona Arlinton

---

## Before resubmitting (checklist, not part of the reply)

- [ ] Record on a physical iPhone on the latest iOS (Control Center → Screen
      Recording). Start from the Home Screen tapping the app icon. Delete and
      reinstall first so onboarding appears. Follow steps 1–6 above.
- [x] Trip banner images (`img_banner*`, `img_korea`) replaced with original
      illustrations made for this app.
- [x] Onboarding image (`img_boardingscreen`) replaced with an original
      illustration.
- [x] App set to iPhone only (TARGETED_DEVICE_FAMILY = 1); only iPhone
      screenshots are needed.
- [x] Widget gallery name renamed from "hh – Next Document" to "SwiftTrip".
- [x] Removed the unused `hh://scan` deep link and its placeholder sheet.
- [ ] App Privacy in App Store Connect: "Data Not Collected" matches this app.
- [x] Privacy manifests added (`hh/PrivacyInfo.xcprivacy`,
      `SwiftTripWidget/PrivacyInfo.xcprivacy`): no tracking, no collected
      data, UserDefaults reasons CA92.1 / 1C8F.1.
- [ ] Screenshots show real in-app screens (trip list, document details,
      widget), not only the onboarding screen.
