@echo off
setlocal
echo ==========================================
echo MangoGrade Flutter - Android Setup
echo ==========================================
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter was not found in PATH.
  echo Open a terminal where the flutter command works, then run this file again.
  pause
  exit /b 1
)

echo.
echo Creating/updating Android host files...
flutter create . --platforms=android --org com.mangograde

if errorlevel 1 (
  echo.
  echo ERROR: flutter create failed.
  pause
  exit /b 1
)

echo.
echo Getting Flutter packages...
flutter pub get

if errorlevel 1 (
  echo.
  echo ERROR: flutter pub get failed.
  pause
  exit /b 1
)

echo.
echo ==========================================
echo READY.
echo Open this folder in Android Studio and Run.
echo Or execute: flutter run
echo ==========================================
pause
