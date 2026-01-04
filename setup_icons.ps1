# PowerShell Script to setup App Icon and Splash Screen
# Salsa CRM - App Icon & Splash Setup

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Salsa CRM - Icon & Splash Setup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
Write-Host "[1/5] Checking Flutter installation..." -ForegroundColor Yellow
try {
    $flutterVersion = flutter --version 2>&1 | Select-String "Flutter"
    Write-Host "✓ Flutter found: $flutterVersion" -ForegroundColor Green
} catch {
    Write-Host "✗ Flutter not found in PATH!" -ForegroundColor Red
    Write-Host "Please install Flutter or add it to your PATH" -ForegroundColor Red
    exit 1
}

# Check if logo files exist
Write-Host ""
Write-Host "[2/5] Checking logo files..." -ForegroundColor Yellow
$logoFiles = @(
    "assets\icon\app_icon.png",
    "assets\icon\app_icon_foreground.png",
    "assets\icon\splash_logo.png"
)

$allFilesExist = $true
foreach ($file in $logoFiles) {
    if (Test-Path $file) {
        Write-Host "  ✓ $file" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $file - NOT FOUND!" -ForegroundColor Red
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Host ""
    Write-Host "⚠ Warning: Some logo files are missing!" -ForegroundColor Yellow
    Write-Host "Please create the logo files before running this script." -ForegroundColor Yellow
    Write-Host "See: assets\icon\README_LOGO_CREATION.md for instructions" -ForegroundColor Yellow
    Write-Host ""
    $continue = Read-Host "Do you want to continue anyway? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Setup cancelled." -ForegroundColor Red
        exit 1
    }
}

# Run flutter pub get
Write-Host ""
Write-Host "[3/5] Installing dependencies..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to install dependencies!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Dependencies installed successfully" -ForegroundColor Green

# Generate app icons
Write-Host ""
Write-Host "[4/5] Generating app icons..." -ForegroundColor Yellow
flutter pub run flutter_launcher_icons
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to generate app icons!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ App icons generated successfully" -ForegroundColor Green

# Generate splash screens
Write-Host ""
Write-Host "[5/5] Generating splash screens..." -ForegroundColor Yellow
flutter pub run flutter_native_splash:create
if ($LASTEXITCODE -ne 0) {
    Write-Host "✗ Failed to generate splash screens!" -ForegroundColor Red
    exit 1
}
Write-Host "✓ Splash screens generated successfully" -ForegroundColor Green

# Clean build
Write-Host ""
Write-Host "[Cleanup] Running flutter clean..." -ForegroundColor Yellow
flutter clean
Write-Host "✓ Build cleaned" -ForegroundColor Green

# Summary
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Setup Complete! 🎉" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run: flutter run" -ForegroundColor White
Write-Host "2. Check the app icon on your home screen" -ForegroundColor White
Write-Host "3. Check the splash screen when launching" -ForegroundColor White
Write-Host ""
Write-Host "If icons don't update:" -ForegroundColor Yellow
Write-Host "- Uninstall the app from your device" -ForegroundColor White
Write-Host "- Run: flutter run" -ForegroundColor White
Write-Host ""
