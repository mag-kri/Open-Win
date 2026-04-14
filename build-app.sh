#!/bin/bash
set -e

APP_NAME="BetterMac"
VERSION=$(cat VERSION 2>/dev/null || echo "1.0.0")
GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "nogit")
BUILD_STAMP=$(date -u +"%Y%m%d-%H%M%S")
LOCAL_BUILD_CODE="${VERSION}-${BUILD_STAMP}-${GIT_SHA}"
ICON_VARIANT="${ICON_VARIANT:-standard}"
APP_DIR="$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME release..."
swift build -c release 2>&1

echo "Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy binary
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"

# Create Info.plist
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>BetterMac</string>
    <key>CFBundleDisplayName</key>
    <string>BetterMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.bettermac.app</string>
    <key>CFBundleVersion</key>
    <string>${LOCAL_BUILD_CODE}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>BetterMacLocalBuildCode</key>
    <string>${LOCAL_BUILD_CODE}</string>
    <key>CFBundleExecutable</key>
    <string>BetterMac</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

# Generate app icon using Swift
echo "Generating app icon..."
cat > /tmp/gen_icon.swift << 'ICONSCRIPT'
import Cocoa

let iconVariant = CommandLine.arguments[2]

func generateIcon(size: Int, scale: Int, outputPath: String) {
    let s = CGFloat(size * scale)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    // Background - rounded blue gradient
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * 0.2
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.02, dy: s * 0.02), xRadius: cornerRadius, yRadius: cornerRadius)

    let gradient: NSGradient
    if iconVariant == "pkg" {
        gradient = NSGradient(colors: [
            NSColor(red: 0.98, green: 0.56, blue: 0.18, alpha: 1.0),
            NSColor(red: 0.86, green: 0.28, blue: 0.13, alpha: 1.0),
        ])!
    } else {
        gradient = NSGradient(colors: [
            NSColor(red: 0.15, green: 0.45, blue: 0.95, alpha: 1.0),
            NSColor(red: 0.10, green: 0.30, blue: 0.85, alpha: 1.0),
        ])!
    }
    gradient.draw(in: bgPath, angle: -45)

    // Draw grid lines (2x2 zones look)
    NSColor.white.withAlphaComponent(0.9).setStroke()
    let lineWidth = s * 0.03

    // Vertical center line
    let vLine = NSBezierPath()
    vLine.move(to: NSPoint(x: s / 2, y: s * 0.22))
    vLine.line(to: NSPoint(x: s / 2, y: s * 0.78))
    vLine.lineWidth = lineWidth
    vLine.lineCapStyle = .round
    vLine.stroke()

    // Horizontal center line
    let hLine = NSBezierPath()
    hLine.move(to: NSPoint(x: s * 0.22, y: s / 2))
    hLine.line(to: NSPoint(x: s * 0.78, y: s / 2))
    hLine.lineWidth = lineWidth
    hLine.lineCapStyle = .round
    hLine.stroke()

    // Outer border
    let border = NSBezierPath(roundedRect: rect.insetBy(dx: s * 0.18, dy: s * 0.18), xRadius: s * 0.06, yRadius: s * 0.06)
    border.lineWidth = lineWidth
    NSColor.white.withAlphaComponent(0.85).setStroke()
    border.stroke()

    // Highlight one quadrant
    let highlight = NSBezierPath(roundedRect: NSRect(x: s * 0.19, y: s * 0.51, width: s * 0.3, height: s * 0.3), xRadius: s * 0.04, yRadius: s * 0.04)
    NSColor.white.withAlphaComponent(0.25).setFill()
    highlight.fill()

    if iconVariant == "pkg" {
        let badgeRect = NSRect(x: s * 0.54, y: s * 0.14, width: s * 0.28, height: s * 0.20)
        let badge = NSBezierPath(roundedRect: badgeRect, xRadius: s * 0.05, yRadius: s * 0.05)
        NSColor.white.withAlphaComponent(0.92).setFill()
        badge.fill()

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: s * 0.09, weight: .bold),
            .foregroundColor: NSColor(red: 0.74, green: 0.23, blue: 0.10, alpha: 1.0),
            .paragraphStyle: paragraph,
        ]
        let text = NSString(string: "PKG")
        let textRect = NSRect(x: badgeRect.origin.x, y: badgeRect.origin.y + s * 0.042, width: badgeRect.width, height: badgeRect.height)
        text.draw(in: textRect, withAttributes: attrs)
    }

    image.unlockFocus()

    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: outputPath))
}

// Generate iconset
let iconsetPath = CommandLine.arguments[1]
let sizes: [(Int, Int)] = [
    (16, 1), (16, 2),
    (32, 1), (32, 2),
    (128, 1), (128, 2),
    (256, 1), (256, 2),
    (512, 1), (512, 2),
]

for (size, scale) in sizes {
    let suffix = scale == 1 ? "" : "@2x"
    let path = "\(iconsetPath)/icon_\(size)x\(size)\(suffix).png"
    generateIcon(size: size, scale: scale, outputPath: path)
}
ICONSCRIPT

ICONSET="$RESOURCES/AppIcon.iconset"
mkdir -p "$ICONSET"
swift /tmp/gen_icon.swift "$ICONSET" "$ICON_VARIANT" 2>/dev/null || echo "Warning: Icon generation skipped (needs GUI session)"

# Convert iconset to icns
if [ -d "$ICONSET" ] && [ "$(ls -A $ICONSET 2>/dev/null)" ]; then
    iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns" 2>/dev/null || echo "Warning: iconutil skipped"
    rm -rf "$ICONSET"
fi

# Clean up
rm -f /tmp/gen_icon.swift

# Code sign (ad-hoc) so macOS can track Accessibility permission
echo "Code signing..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "$APP_NAME.app created successfully!"
echo "Location: $(pwd)/$APP_DIR"
echo ""
echo "To install, drag BetterMac.app to /Applications"
echo "Or run: cp -r $APP_DIR /Applications/"
echo ""
echo "First launch: Allow Accessibility access in System Settings"
