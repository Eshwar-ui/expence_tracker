# ============================================
# STEP-BY-STEP GUIDE TO FIX PLAY STORE ISSUE
# ============================================

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Play Store Release Signing Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "PROBLEM:" -ForegroundColor Red
Write-Host "Your app is currently signed with a DEBUG certificate." -ForegroundColor Yellow
Write-Host "Play Store REQUIRES a proper RELEASE certificate." -ForegroundColor Yellow
Write-Host ""

Write-Host "SOLUTION:" -ForegroundColor Green
Write-Host "We need to create a release keystore and configure your build." -ForegroundColor White
Write-Host ""

# Step 1: Generate Keystore
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 1: Generate Release Keystore" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "This will create a file called 'upload-keystore.jks'" -ForegroundColor White
Write-Host "You will be asked for:" -ForegroundColor White
Write-Host "  - Password (choose a strong one and REMEMBER IT!)" -ForegroundColor Yellow
Write-Host "  - Your name" -ForegroundColor Yellow
Write-Host "  - Organization (can be your name)" -ForegroundColor Yellow
Write-Host "  - City, State, Country" -ForegroundColor Yellow
Write-Host ""

$keystorePath = "android\app\upload-keystore.jks"
$fullKeystorePath = Join-Path $PSScriptRoot $keystorePath

Write-Host "Keystore will be created at:" -ForegroundColor White
Write-Host "  $fullKeystorePath" -ForegroundColor Cyan
Write-Host ""

$response = Read-Host "Ready to generate keystore? (y/n)"
if ($response -eq 'y' -or $response -eq 'Y') {
    Write-Host ""
    Write-Host "Generating keystore..." -ForegroundColor Green
    Write-Host ""
    
    $command = "keytool -genkey -v -keystore `"$fullKeystorePath`" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload"
    
    Invoke-Expression $command
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Keystore generated successfully!" -ForegroundColor Green
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "✗ Failed to generate keystore" -ForegroundColor Red
        Write-Host "Make sure you have Java/JDK installed" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Skipping keystore generation..." -ForegroundColor Yellow
    Write-Host ""
}

# Step 2: Create key.properties
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 2: Create key.properties File" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$keyPropertiesPath = "android\key.properties"
$fullKeyPropertiesPath = Join-Path $PSScriptRoot $keyPropertiesPath

if (Test-Path $fullKeyPropertiesPath) {
    Write-Host "key.properties already exists!" -ForegroundColor Yellow
    $overwrite = Read-Host "Overwrite? (y/n)"
    if ($overwrite -ne 'y' -and $overwrite -ne 'Y') {
        Write-Host "Skipping key.properties creation..." -ForegroundColor Yellow
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "Enter the password you used for the keystore:" -ForegroundColor White
        $storePassword = Read-Host -AsSecureString
        $storePwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))
        
        Write-Host "Enter the key password (usually same as store password):" -ForegroundColor White
        $keyPassword = Read-Host -AsSecureString
        $keyPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))
        
        $keyPropertiesContent = @"
storePassword=$storePwd
keyPassword=$keyPwd
keyAlias=upload
storeFile=upload-keystore.jks
"@
        
        $keyPropertiesContent | Out-File -FilePath $fullKeyPropertiesPath -Encoding UTF8
        Write-Host ""
        Write-Host "✓ key.properties created successfully!" -ForegroundColor Green
        Write-Host ""
    }
} else {
    Write-Host "Creating key.properties file..." -ForegroundColor White
    Write-Host ""
    Write-Host "Enter the password you used for the keystore:" -ForegroundColor White
    $storePassword = Read-Host -AsSecureString
    $storePwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($storePassword))
    
    Write-Host "Enter the key password (usually same as store password):" -ForegroundColor White
    $keyPassword = Read-Host -AsSecureString
    $keyPwd = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($keyPassword))
    
    $keyPropertiesContent = @"
storePassword=$storePwd
keyPassword=$keyPwd
keyAlias=upload
storeFile=upload-keystore.jks
"@
    
    $keyPropertiesContent | Out-File -FilePath $fullKeyPropertiesPath -Encoding UTF8
    Write-Host ""
    Write-Host "✓ key.properties created successfully!" -ForegroundColor Green
    Write-Host ""
}

# Step 3: Build Release
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 3: Build Release App Bundle" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Now we'll build the release App Bundle (.aab)" -ForegroundColor White
Write-Host "This is what you'll upload to Play Store" -ForegroundColor White
Write-Host ""

$buildResponse = Read-Host "Build App Bundle now? (y/n)"
if ($buildResponse -eq 'y' -or $buildResponse -eq 'Y') {
    Write-Host ""
    Write-Host "Building App Bundle..." -ForegroundColor Green
    Write-Host "This may take a few minutes..." -ForegroundColor Yellow
    Write-Host ""
    
    flutter build appbundle --release --no-tree-shake-icons
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ App Bundle built successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Location:" -ForegroundColor White
        Write-Host "  build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "✗ Build failed" -ForegroundColor Red
        Write-Host "Check the error messages above" -ForegroundColor Yellow
        exit 1
    }
} else {
    Write-Host "Skipping build..." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You can build later with:" -ForegroundColor White
    Write-Host "  flutter build appbundle --release --no-tree-shake-icons" -ForegroundColor Cyan
    Write-Host ""
}

# Step 4: Verify Signing
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "STEP 4: Verify Signing" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$aabPath = "build\app\outputs\bundle\release\app-release.aab"
$fullAabPath = Join-Path $PSScriptRoot $aabPath

if (Test-Path $fullAabPath) {
    Write-Host "Verifying App Bundle signature..." -ForegroundColor White
    Write-Host ""
    
    jarsigner -verify -verbose -certs $fullAabPath
    
    Write-Host ""
    Write-Host "Check the output above:" -ForegroundColor White
    Write-Host "  - Should NOT say 'CN=Android Debug'" -ForegroundColor Yellow
    Write-Host "  - Should show your name/organization" -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "App Bundle not found. Build it first!" -ForegroundColor Yellow
    Write-Host ""
}

# Final Instructions
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "NEXT STEPS" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1. BACKUP YOUR KEYSTORE:" -ForegroundColor Yellow
Write-Host "   - Copy 'android\app\upload-keystore.jks' to a safe location" -ForegroundColor White
Write-Host "   - Save your passwords securely" -ForegroundColor White
Write-Host "   - If you lose this, you CANNOT update your app!" -ForegroundColor Red
Write-Host ""

Write-Host "2. UPLOAD TO PLAY STORE:" -ForegroundColor Yellow
Write-Host "   - Go to Google Play Console" -ForegroundColor White
Write-Host "   - Upload: build\app\outputs\bundle\release\app-release.aab" -ForegroundColor Cyan
Write-Host ""

Write-Host "3. FOR FUTURE UPDATES:" -ForegroundColor Yellow
Write-Host "   - Increment version in pubspec.yaml" -ForegroundColor White
Write-Host "   - Run: flutter build appbundle --release --no-tree-shake-icons" -ForegroundColor Cyan
Write-Host "   - Upload new .aab to Play Store" -ForegroundColor White
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host "Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
