# MangoGrade Flutter

MangoGrade is a Flutter implementation of the Figma high-fidelity HCI for mango quality classification.

## Current build

This downloadable version is intentionally runnable before the trained AI model is added.

Included:
- Splash screen
- Home dashboard
- Scan screen
- Processing screen
- Dynamic result screen
- History screen
- PNS/BAFS 13:2024 grading guide UI
- About MobileNetV3 screen
- Settings screen
- Extra Class / Class I / Class II / Reject Class result support
- Fully offline demo flow

Not yet connected:
- Real phone camera
- Gallery picker
- Real `.tflite` MobileNetV3 model
- Persistent SQLite history

The `MangoClassifier` service is isolated so the real model can be connected later without redesigning the GUI.

## First-time setup

This ZIP contains the complete Flutter source. Run this once from the project root:

### Windows
```bat
setup_project.bat
```

### macOS / Linux
```bash
chmod +x setup_project.sh
./setup_project.sh
```

The script runs:

```bash
flutter create . --platforms=android --org com.mangograde
flutter pub get
```

This generates the Android host project using the Flutter version already installed on your computer.

## Android Studio

1. Extract the ZIP.
2. Run `setup_project.bat` once.
3. Open Android Studio.
4. Choose **Open** and select the `MangoGradeFlutter` folder.
5. Wait for Flutter/Gradle synchronization.
6. Select your Android phone or emulator.
7. Press **Run ▶**.

You can also run:

```bash
flutter run
```

## Demo classification

On **Scan Mango**, press **Analyze Demo Mango**.

The demo classifier cycles through:
- Extra Class
- Class I
- Class II
- Reject Class

This is only to test the UI and navigation. Replace `lib/services/mango_classifier.dart` when your MobileNetV3 TFLite model is ready.
