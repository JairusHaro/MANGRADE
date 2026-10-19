# MangGrade Flutter

MangGrade is a Flutter prototype for mango quality classification using the four app classes: Extra Class, Class I, Class II, and Reject Class.

## Current status

The app can be run before the trained model is ready.

Included:
- Splash screen and home dashboard
- Camera capture and gallery image selection through `image_picker`
- Selected-image preview
- Processing and result screens
- Explicit warning that current grades/confidence are simulated demo values
- History screen and in-memory demo history
- PNS/BAFS 13:2024 visual-reference guide UI
- About and settings screens
- Starter Flutter unit tests

Not yet implemented:
- Trained MobileNetV3 TensorFlow Lite inference
- Persistent scan history (current history is in memory)
- Verified model preprocessing, normalization, labels, and evaluation
- A production database or user accounts

**Important:** The current classifier cycles through sample grades and confidence values. It does not inspect the selected image. Do not use demo results as real grading outcomes or model-evaluation data.

## Setup

From the Flutter project root, run:

```bash
flutter pub get
flutter test
flutter run
```

`image_picker` is listed in `pubspec.yaml`. Run `flutter pub get` to update `pubspec.lock` for the current dependency set.

## Demo workflow

1. Open **Scan Mango**.
2. Choose **Camera** to take a photo or **Gallery** to select an image.
3. Review the image preview.
4. Tap **Run Demo Classification**.
5. The result screen shows the selected image and a clear demo-result warning.

The returned class/confidence are simulated to let you test navigation and the UI while the trained model is being prepared.

## Planned on-device model integration

The README's intended architecture is on-device TensorFlow Lite inference. The planned integration point is `lib/services/mango_classifier.dart`.

When the model is ready:
1. Add the trained `.tflite` model under the configured Flutter assets directory.
2. Add and pin the chosen TFLite runtime dependency.
3. Implement preprocessing to match training exactly (input dimensions, color channel order, and normalization).
4. Load the model and map output indices to the approved class labels.
5. Mark results as non-demo only after actual inference succeeds.
6. Test the model on a separate held-out evaluation set.

Do not label the app as using MobileNetV3 inference until the model is actually loaded and used.

## Optional FastAPI prototype

The `backend/` folder contains a separate FastAPI image-validation prototype. It currently validates uploaded images but **does not make predictions**. The main README architecture is on-device inference, so Flutter is not connected to this API.

From the `backend/` directory:

```bash
python -m venv .venv
```

Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
python -m uvicorn main:app --reload
```

Open `http://127.0.0.1:8000/docs` to inspect the API. For an Android emulator, the host machine is typically reached at `http://10.0.2.2:8000`; a physical phone needs the computer's LAN IP and both devices on the same network. The API URL must not use `127.0.0.1` from the phone/emulator.

The API's `/predict` response intentionally returns `predicted_grade: null` until a real backend model is connected.

## Tests

Run Flutter tests with:

```bash
flutter test
```

The included starter tests cover class display labels, demo metadata, and in-memory history behavior. They do not evaluate model accuracy.
