# App Store Connect: App Privacy and Accessibility

Answers for the **App Privacy** and **Accessibility** sections of SwiftTrip's App Store page. Re-check them whenever the app changes.

---

## App Privacy ("Privacy Nutrition Label")

**App Store Connect → your app → App Privacy → Get Started**

| Question | Answer |
|---|---|
| Do you or your third-party partners collect data from this app? | **No, we do not collect data from this app** |
| Privacy Policy URL | Host `docs/privacy-policy.md` (for example on GitHub Pages or Notion) and paste its public URL |

**Result on the App Store page:** "Data Not Collected".

### Why this is accurate (checked in the code)

- **No network calls:** there is no `URLSession`. There are no analytics, crash-reporting or ad SDKs, and no Swift packages.
- **OCR and classification run on the device:** Vision, the PDF's own text layer, and Apple's on-device Foundation Models.
- **Debug-only recorder:** `TrainingSampleRecorder` runs only in DEBUG builds and never sends anything.
- **Privacy manifests:**
  - `hh/PrivacyInfo.xcprivacy` and `SwiftTripWidget/PrivacyInfo.xcprivacy` declare no tracking and no collected data.
  - They also declare UserDefaults use with reasons `CA92.1` (the app's own settings) and `1C8F.1` (the App Group shared with the widget).

> If you ever add analytics, crash reporting, sign-in or cloud sync, you must update this label and the privacy manifests before release.

---

## Accessibility ("Accessibility Nutrition Labels")

**App Store Connect → your app → Accessibility → Add device (iPhone)**

Only claim a feature after **testing every common task with it turned on**. The common tasks are:

1. scanning with the camera
2. importing from Photos or Files (including PDFs)
3. confirming or changing the category
4. editing the details and saving
5. opening a saved document and zooming
6. creating a trip
7. using the widget

| Feature | Claim? | Notes / how to verify |
|---|---|---|
| **VoiceOver** | ✅ after testing | Icon-only buttons now have labels: scan, add, clear search, discard, save trip, delete trip, remove category, close viewer. Document images announce their name and "opens full screen with zoom". Decorative onboarding images are hidden. Test: Settings ▸ Accessibility ▸ VoiceOver, then do every task above. |
| **Voice Control** | ✅ after testing | Uses the same labels, e.g. say "Tap Scan document". Test: Settings ▸ Accessibility ▸ Voice Control. |
| **Larger Text** | ⚠️ test first | Text uses Dynamic Type styles. The fixed 36 pt times and 22 pt "+" now scale. The trip cards have a fixed 280×160 size. Check that nothing is cut off at the largest accessibility text size (Settings ▸ Accessibility ▸ Display & Text Size ▸ Larger Text). |
| **Dark Interface** | ✅ after testing | Uses system colours and materials. Check every screen in Dark Mode. |
| **Differentiate Without Color Alone** | ✅ | Categories always show an icon and a name. Trip status is written as text, not only shown as a colour. |
| **Sufficient Contrast** | ⚠️ test first | Check the secondary grey text and the white text on photo banners. Use Accessibility Inspector ▸ Audit in Xcode. |
| **Reduced Motion** | ✅ | Only short fades and scales are used. There is no parallax, auto-playing or looping animation. |
| **Captions** | ❌ Not applicable | The app has no video or audio. |
| **Audio Descriptions** | ❌ Not applicable | The app has no video. |

### Quick audit in Xcode

1. Run the app in the Simulator.
2. Open **Xcode ▸ Open Developer Tool ▸ Accessibility Inspector**.
3. Pick the Simulator and choose **Audit**.
4. Fix any warnings on the main screens before you claim a feature.

---

## Other submission settings (already set in the project)

- **Privacy manifests:** present for both the app and the widget.
- **Devices:** iPhone only (`TARGETED_DEVICE_FAMILY = 1`), so no iPad screenshots are needed.
- **Widget name:** shows as "SwiftTrip – Next Document" in the widget gallery.
- **Camera permission text:** "We use the camera to scan travel documents".
