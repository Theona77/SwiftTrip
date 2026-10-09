# Document classifier training

The app classifies scans in four steps (`hh/Service/DocumentClassifier.swift`):

1. **MRZ.** The machine-readable lines on passports, visas and ID cards are parsed by `MRZParser`, and their check digits are verified.
2. **Unambiguous phrases.** For example "BOARDING PASS" or "KARTU TANDA PENDUDUK".
3. **The Create ML text classifier.** The model is `DocumentTypeClassifier.mlmodel`. This step is used only when the model is bundled and its confidence is at least 0.6.
4. **Weighted whole-word keyword scoring.** This is the fallback. The result is "Others" when the evidence is weak.

Until a model is bundled, step 3 is skipped. The app still works with steps 1, 2 and 4.

## 1. Collect data

Debug builds record every saved scan to `Documents/ClassifierTraining/samples.json`. Each record contains the OCR text in normalised form, the category the user confirmed, and what the classifier predicted. The recorder is `hh/Service/TrainingSampleRecorder.swift`.

To get the file off the phone:

1. In Xcode, open **Window ▸ Devices and Simulators**.
2. Select **hh** and choose **Download Container…**.
3. Copy the file from `AppData/Documents/ClassifierTraining/samples.json`.

> The samples contain personal data from IDs and passports. Keep them out of git. `*.mlmodel` files are fine to commit; the training data is not.

Aim for **at least 50 samples per category**, and 100–200 for the categories that look alike: hotel, reservation, activity and event. Include messy scans: blurred, rotated, cropped and screenshots. Include both Indonesian and English documents.

`sample_training_data.json` shows the format with 3 synthetic examples per category. It is only good enough to check that the pipeline runs.

## 2. Train (on a Mac with Xcode)

```sh
cd Tools/DocumentClassifierTraining
swift train.swift samples.json [more.json ...] --out DocumentTypeClassifier.mlmodel
```

- By default the script uses **transfer learning on BERT embeddings**. The embeddings are multilingual and ship with iOS 17 and later, so the model file is small, about 1 MB.
- Add `--maxent` for a tiny Maximum Entropy model. It trains faster and suits small datasets, but is less accurate.

The script prints the following:

- Accuracy on the training, validation and test splits.
- Precision and recall for each category.
- A confusion matrix.

Look at the confusion matrix to see which categories need more data.

## 3. Ship

Drag `DocumentTypeClassifier.mlmodel` into the `hh/` folder in Xcode. The folder is synchronised, so the file is added to the target automatically. Xcode compiles it to `DocumentTypeClassifier.mlmodelc`, and `DocumentTextClassifier` loads it at launch.

## Rules

- Labels must match `DocumentCategory.trainingLabel`: `nationalID passport visa boardingPass hotel train reservation activity event other`.
- `DocumentTextClassifier.normalise` in the app and `normalise` in `train.swift` must stay identical. If you change one, change the other and retrain.
