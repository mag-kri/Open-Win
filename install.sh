#!/bin/bash
set -e

echo "=== BetterMac Installer ==="
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

echo "Building BetterMac..."
swift build -c release

echo "Installing to /usr/local/bin/bettermac..."
sudo cp .build/release/BetterMac /usr/local/bin/bettermac
sudo chmod +x /usr/local/bin/bettermac

echo ""
echo "=== Installation complete! ==="
echo ""
echo "Start BetterMac:"
echo "  bettermac &"
echo ""
echo "IMPORTANT: Grant Accessibility permission on first launch:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Add and enable 'bettermac' (or your terminal app)"
echo ""
