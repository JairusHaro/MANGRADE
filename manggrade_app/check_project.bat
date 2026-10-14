@echo off
echo Checking Flutter...
flutter --version
echo.
echo Running flutter analyze...
flutter analyze
echo.
echo If there are no errors, the MangoGrade source is ready.
pause
