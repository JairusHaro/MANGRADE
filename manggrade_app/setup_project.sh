#!/usr/bin/env bash
set -e
echo "MangoGrade Flutter - Android Setup"
command -v flutter >/dev/null 2>&1 || { echo "Flutter is not available in PATH."; exit 1; }
flutter create . --platforms=android --org com.mangograde
flutter pub get
echo "Ready. Open this folder in Android Studio or run: flutter run"
