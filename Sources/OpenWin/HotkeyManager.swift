import Cocoa
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    var onToggleOverlay: (() -> Void)?
    var onZoneEditor: (() -> Void)?
    var onScreenCapture: (() -> Void)?
    var onAltTab: (() -> Void)?
    var onAltTabCycle: (() -> Void)?
    var altTabActive = false

    // Shift-hold callbacks (for drag-snap)
    var onShiftDown: (() -> Void)?
    var onShiftUp: (() -> Void)?

    private var shiftIsDown = false

    func start() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.flagsChanged.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon!).takeUnretainedValue()

                // Log every event type we receive
                if type != .keyDown { // Don't spam with keyDown
                    zlog("[Hotkey] EVENT type=\(type.rawValue)")
                }

                // Re-enable tap if it got disabled
                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = manager.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                        zlog("[Hotkey] Re-enabled tap after disable")
                    }
                    return Unmanaged.passRetained(event)
                }

                if type == .flagsChanged {
                    manager.handleFlagsChanged(event)
                    return Unmanaged.passRetained(event) // don't consume
                }

                if type == .leftMouseUp {
                    manager.handleMouseUp()
                    return Unmanaged.passRetained(event)
                }

                if type == .keyDown {
                    if manager.handleKeyEvent(event) {
                        return nil // consume hotkey
                    }
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            zlog("[Hotkey] FAILED to create event tap! mask=\(mask)")
            return
        }

        zlog("[Hotkey] Tap created with mask=\(mask) (flagsChanged=\(CGEventType.flagsChanged.rawValue), mouseUp=\(CGEventType.leftMouseUp.rawValue), keyDown=\(CGEventType.keyDown.rawValue))")

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        zlog("[Hotkey] Event tap started (keyDown + flagsChanged + mouseUp)")
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes) }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Shift detection for drag-snap

    private func handleFlagsChanged(_ event: CGEvent) {
        let shiftDown = event.flags.contains(.maskShift)

        if shiftDown && !shiftIsDown {
            shiftIsDown = true
            zlog("[Hotkey] Shift DOWN")
            DispatchQueue.main.async { [weak self] in
                self?.onShiftDown?()
            }
        } else if !shiftDown && shiftIsDown {
            shiftIsDown = false
            zlog("[Hotkey] Shift UP")
            DispatchQueue.main.async { [weak self] in
                self?.onShiftUp?()
            }
        }
    }

    private func handleMouseUp() {
        if shiftIsDown {
            zlog("[Hotkey] MouseUp while Shift held")
            // Let DragManager handle this via its own monitoring
        }
    }

    // MARK: - Keyboard shortcuts (Ctrl+Option)

    private func handleKeyEvent(_ event: CGEvent) -> Bool {
        let flags = event.flags
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        let hasControl = flags.contains(.maskControl)
        let hasOption = flags.contains(.maskAlternate)
        let hasShift = flags.contains(.maskShift)
        let noCmd = !flags.contains(.maskCommand)

        // ⌥Tab — Alt+Tab window switcher
        if hasOption && !hasControl && noCmd && keyCode == 48 {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                if self.altTabActive {
                    if hasShift {
                        self.onAltTabCycle?() // signal: go backward (we'll handle in AppDelegate)
                    } else {
                        self.onAltTabCycle?()
                    }
                } else {
                    self.onAltTab?()
                }
            }
            return true
        }

        // ⇧⌥S — Screenshot
        if hasShift && hasOption && !hasControl && noCmd && keyCode == 1 {
            DispatchQueue.main.async { [weak self] in
                self?.onScreenCapture?()
            }
            return true
        }

        // ⌃⌥ shortcuts (no Shift, no Cmd)
        guard hasControl && hasOption && noCmd && !hasShift else { return false }

        let wm = WindowManager.shared

        switch keyCode {
        case 123: wm.moveLeft(); return true
        case 124: wm.moveRight(); return true
        case 126: wm.moveTop(); return true
        case 125: wm.moveBottom(); return true
        case 32: wm.moveTopLeft(); return true
        case 34: wm.moveTopRight(); return true
        case 38: wm.moveBottomLeft(); return true
        case 40: wm.moveBottomRight(); return true
        case 8: wm.moveCenter(); return true
        case 36: wm.maximize(); return true
        case 14: // E - zone editor
            DispatchQueue.main.async { [weak self] in
                self?.onZoneEditor?()
            }
            return true
        case 6: // Z
            DispatchQueue.main.async { [weak self] in
                self?.onToggleOverlay?()
            }
            return true
        default:
            return false
        }
    }
}
