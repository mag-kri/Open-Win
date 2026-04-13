#!/bin/bash
set -e

echo "=== OpenWin Installer ==="
echo ""

# Check Swift
if ! command -v swift &>/dev/null; then
    echo "Error: Swift is required. Install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Check macOS version
OS_VER=$(sw_vers -productVersion | cut -d. -f1)
if [ "$OS_VER" -lt 13 ]; then
    echo "Error: macOS 13 (Ventura) or later is required."
    exit 1
fi

echo "Building OpenWin..."
swift build -c release

echo "Installing to /usr/local/bin/openwin..."
sudo cp .build/release/OpenWin /usr/local/bin/openwin
sudo chmod +x /usr/local/bin/openwin

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Start OpenWin:"
echo "  openwin &"
echo ""
echo "IMPORTANT: Grant Accessibility permission on first launch:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Add and enable 'openwin' (or your terminal app)"
echo ""
