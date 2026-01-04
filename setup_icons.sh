#!/bin/bash
# Bash Script to setup App Icon and Splash Screen
# Salsa CRM - App Icon & Splash Setup

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================"
echo -e "  Salsa CRM - Icon & Splash Setup"
echo -e "========================================${NC}"
echo ""

# Check if Flutter is installed
echo -e "${YELLOW}[1/5] Checking Flutter installation...${NC}"
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}✗ Flutter not found in PATH!${NC}"
    echo -e "${RED}Please install Flutter or add it to your PATH${NC}"
    exit 1
fi
flutter_version=$(flutter --version 2>&1 | head -n 1)
echo -e "${GREEN}✓ Flutter found: $flutter_version${NC}"

# Check if logo files exist
echo ""
echo -e "${YELLOW}[2/5] Checking logo files...${NC}"
logo_files=(
    "assets/icon/app_icon.png"
    "assets/icon/app_icon_foreground.png"
    "assets/icon/splash_logo.png"
)

all_files_exist=true
for file in "${logo_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "  ${GREEN}✓ $file${NC}"
    else
        echo -e "  ${RED}✗ $file - NOT FOUND!${NC}"
        all_files_exist=false
    fi
done

if [ "$all_files_exist" = false ]; then
    echo ""
    echo -e "${YELLOW}⚠ Warning: Some logo files are missing!${NC}"
    echo -e "${YELLOW}Please create the logo files before running this script.${NC}"
    echo -e "${YELLOW}See: assets/icon/README_LOGO_CREATION.md for instructions${NC}"
    echo ""
    read -p "Do you want to continue anyway? (y/N): " continue
    if [[ ! "$continue" =~ ^[Yy]$ ]]; then
        echo -e "${RED}Setup cancelled.${NC}"
        exit 1
    fi
fi

# Run flutter pub get
echo ""
echo -e "${YELLOW}[3/5] Installing dependencies...${NC}"
flutter pub get
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to install dependencies!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Dependencies installed successfully${NC}"

# Generate app icons
echo ""
echo -e "${YELLOW}[4/5] Generating app icons...${NC}"
flutter pub run flutter_launcher_icons
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to generate app icons!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ App icons generated successfully${NC}"

# Generate splash screens
echo ""
echo -e "${YELLOW}[5/5] Generating splash screens...${NC}"
flutter pub run flutter_native_splash:create
if [ $? -ne 0 ]; then
    echo -e "${RED}✗ Failed to generate splash screens!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Splash screens generated successfully${NC}"

# Clean build
echo ""
echo -e "${YELLOW}[Cleanup] Running flutter clean...${NC}"
flutter clean
echo -e "${GREEN}✓ Build cleaned${NC}"

# Summary
echo ""
echo -e "${CYAN}========================================"
echo -e "  Setup Complete! 🎉"
echo -e "========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "${NC}1. Run: flutter run"
echo -e "2. Check the app icon on your home screen"
echo -e "3. Check the splash screen when launching"
echo ""
echo -e "${YELLOW}If icons don't update:${NC}"
echo -e "${NC}- Uninstall the app from your device"
echo -e "- Run: flutter run"
echo ""
