@echo off
setlocal
echo ========================================================
echo       EXPENSE TRACKER - AUTO DEPLOYMENT TOOL
echo ========================================================
echo.

:: 1. Check if APK exists
echo [1/3] Finding latest APK build...
set "APK_PATH=build\app\outputs\flutter-apk\app-release.apk"
set "ZIP_PATH=website\downloads\expence_tracker.zip"

if not exist "%APK_PATH%" (
    echo [ERROR] APK file not found at: %APK_PATH%
    echo Please run 'flutter build apk --no-tree-shake-icons' first.
    echo.
    pause
    exit /b 1
)

echo    - Found: %APK_PATH%

:: 2. Create Zip File using PowerShell
echo.
echo [2/3] Zipping APK for Firebase Hosting (Spark Plan Compatible)...
powershell -Command "Write-Host '   - Compressing...'; Compress-Archive -Path '%APK_PATH%' -DestinationPath '%ZIP_PATH%' -Force"

if %errorlevel% neq 0 (
    echo [ERROR] Failed to zip the file.
    pause
    exit /b 1
)
echo    - Content zipped to: %ZIP_PATH%

:: 3. Deploy to Firebase
echo.
echo [3/3] Deploying to Firebase Hosting...
echo.
call firebase deploy --only hosting

if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Firebase deployment failed.
    pause
    exit /b 1
)

echo.
echo ========================================================
echo        SUCCESS! Website is live with new APK.
echo ========================================================
echo.
pause
