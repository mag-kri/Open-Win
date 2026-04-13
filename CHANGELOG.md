# Changelog

## v1.3.1 — Click-Through Cursor Fix

### Bug Fix
- **Fixed mouse cursor jumping on click-through**: Clicking a background window (e.g. Spotify) caused the cursor to visibly jump. Root cause was inaccurate coordinate conversion and stale cursor position when re-sending synthetic click events.
  - Cursor position is now read directly in CG coordinates via `CGEvent`, fixing multi-monitor edge cases.
  - Position is re-read at the moment the synthetic click is posted, instead of using a 50ms-old value.

## v1.3.0 — Customizable Shortcuts, Keyboard Profiles, Zone Editor Improvements

### New Features
- Customizable keyboard shortcuts for all window actions
- Keyboard profiles (switch between shortcut sets)
- Zone Editor improvements

## v1.1.0 — Zone Editor, Click-Through, Presets

### New Features
- Zone Editor for custom window layouts
- Windows-style click-through (activate background windows with a single click)
- Window layout presets

## v1.0.0 — Initial Release

### Features
- Window snapping (left, right, top, bottom, corners, center, maximize)
- Alt-Tab window switcher
- Focus follows mouse (optional)
- Drag-to-snap with zone overlays
- Screen capture utility
