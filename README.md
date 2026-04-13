# BetterMac

PowerToys-inspired productivity toolkit for macOS. Window snapping, Alt+Tab switcher, screenshot tool, and focus-follows-mouse — all in one lightweight menu bar app.

## Features

- **Window Snapping** — Hold Shift while dragging a window to snap it to zones (left/right half)
- **Alt+Tab Switcher** — Windows-style window switcher with live thumbnails
- **Screenshot Tool** — Quick screen capture with region/window/fullscreen modes
- **Focus Follows Mouse** — Automatically focus the window under your cursor
- **Keyboard Shortcuts** — Snap windows instantly with hotkeys

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Shift + Drag` | Show zones, snap window on release |
| `Option + Tab` | Alt+Tab window switcher |
| `Shift + Option + S` | Screenshot (Space to switch mode) |
| `Ctrl + Option + Arrow` | Snap to left/right/top/bottom half |
| `Ctrl + Option + U/I/J/K` | Snap to quarter (corners) |
| `Ctrl + Option + C` | Center window |
| `Ctrl + Option + Return` | Maximize window |
| `Ctrl + Option + Z` | Show zone overlay |

## Installation

### Homebrew (recommended)

```bash
brew tap mag-kri/bettermac
brew install bettermac
```

### From Source

```bash
git clone https://github.com/mag-kri/bettermac.git
cd bettermac
make install
```

### Manual

```bash
git clone https://github.com/mag-kri/bettermac.git
cd bettermac
swift build -c release
cp .build/release/BetterMac /usr/local/bin/bettermac
```

## Usage

Start BetterMac from terminal:

```bash
bettermac &
```

A menu bar icon (grid) appears. Right-click for options.

### First Launch

BetterMac needs **Accessibility** permission to manage windows:

1. A macOS dialog will appear asking for permission
2. Go to **System Settings > Privacy & Security > Accessibility**
3. Add and enable BetterMac
4. Restart the app

> **Tip:** Running from terminal inherits the terminal's accessibility permission, which usually works out of the box.

## Building

Requires macOS 13+ and Swift 5.9+.

```bash
make build       # Build release binary
make app         # Build .app bundle
make install     # Install to /usr/local/bin
make clean       # Clean build artifacts
```

## Configuration

Toggle features from the menu bar icon:
- **Focus Follows Mouse** — on/off toggle
- **Quick Actions** — snap windows from the menu
- **Preferences** — startup and layout options

## Requirements

- macOS 13.0 (Ventura) or later
- Accessibility permission (for window management and keyboard shortcuts)

## License

MIT
