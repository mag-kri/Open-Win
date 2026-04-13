import Cocoa
import ApplicationServices

final class WindowManager {
    static let shared = WindowManager()

    /// Get the currently focused window's AXUIElement
    private func focusedWindow() -> AXUIElement? {
        // Try the frontmost app first (more reliable after drag)
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)

        // Try focused window
        var focusedWin: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWin) == .success {
            return (focusedWin as! AXUIElement)
        }

        // Fallback: get first window from window list
        var windowList: AnyObject?
        if AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowList) == .success,
           let windows = windowList as? [AXUIElement],
           let first = windows.first {
            return first
        }

        // Last resort: system-wide focused app
        let systemWide = AXUIElementCreateSystemWide()
        var focusedApp: AnyObject?
        guard AXUIElementCopyAttributeValue(systemWide, kAXFocusedApplicationAttribute as CFString, &focusedApp) == .success else {
            return nil
        }
        let app = focusedApp as! AXUIElement
        var win: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &win) == .success else {
            return nil
        }
        return (win as! AXUIElement)
    }

    /// Get usable screen frame (excluding menu bar and dock)
    func usableScreenFrame() -> CGRect {
        guard let screen = NSScreen.main else { return .zero }
        return screen.visibleFrame
    }

    /// Move and resize the focused window to the given frame
    func moveWindow(to frame: CGRect) {
        let frontApp = NSWorkspace.shared.frontmostApplication
        zlog("[WM] frontApp=\(frontApp?.localizedName ?? "nil") pid=\(frontApp?.processIdentifier ?? 0)")

        guard let window = focusedWindow() else {
            zlog("[WM] ERROR: No focused window found!")
            return
        }

        let screenFrame = NSScreen.main?.frame ?? .zero
        let position = CGPoint(
            x: frame.origin.x,
            y: screenFrame.height - frame.origin.y - frame.height
        )
        let size = CGSize(width: frame.width, height: frame.height)

        zlog("[WM] Moving to pos=\(position) size=\(size)")

        var pos = position
        var sz = size
        let posValue = AXValueCreate(.cgPoint, &pos)!
        let sizeValue = AXValueCreate(.cgSize, &sz)!

        let posResult = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
        let sizeResult = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)

        zlog("[WM] Results: pos=\(posResult.rawValue) size=\(sizeResult.rawValue) (0=success)")
    }

    /// Move focused window to a zone (with toast)
    func moveToZone(_ zone: Zone) {
        let screen = usableScreenFrame()
        let frame = zone.frame(for: screen)
        zlog("[BetterMac] moveToZone '\(zone.name)' → frame=\(frame)")
        let win = focusedWindow()
        zlog("[BetterMac] focusedWindow: \(win != nil ? "FOUND" : "NOT FOUND")")
        moveWindow(to: frame)
        ToastWindow.show(message: zone.name)
    }

    func moveLeft() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x, y: s.origin.y, width: s.width / 2, height: s.height))
        ToastWindow.show(message: "Left Half", icon: "rectangle.lefthalf.filled")
    }

    func moveRight() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x + s.width / 2, y: s.origin.y, width: s.width / 2, height: s.height))
        ToastWindow.show(message: "Right Half", icon: "rectangle.righthalf.filled")
    }

    func moveTop() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x, y: s.origin.y + s.height / 2, width: s.width, height: s.height / 2))
        ToastWindow.show(message: "Top Half", icon: "rectangle.tophalf.filled")
    }

    func moveBottom() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x, y: s.origin.y, width: s.width, height: s.height / 2))
        ToastWindow.show(message: "Bottom Half", icon: "rectangle.bottomhalf.filled")
    }

    func moveTopLeft() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x, y: s.origin.y + s.height / 2, width: s.width / 2, height: s.height / 2))
        ToastWindow.show(message: "Top Left", icon: "rectangle.split.2x2")
    }

    func moveTopRight() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x + s.width / 2, y: s.origin.y + s.height / 2, width: s.width / 2, height: s.height / 2))
        ToastWindow.show(message: "Top Right", icon: "rectangle.split.2x2")
    }

    func moveBottomLeft() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x, y: s.origin.y, width: s.width / 2, height: s.height / 2))
        ToastWindow.show(message: "Bottom Left", icon: "rectangle.split.2x2")
    }

    func moveBottomRight() {
        let s = usableScreenFrame()
        moveWindow(to: CGRect(x: s.origin.x + s.width / 2, y: s.origin.y, width: s.width / 2, height: s.height / 2))
        ToastWindow.show(message: "Bottom Right", icon: "rectangle.split.2x2")
    }

    func moveCenter() {
        let s = usableScreenFrame()
        let w = s.width * 0.6
        let h = s.height * 0.7
        moveWindow(to: CGRect(
            x: s.origin.x + (s.width - w) / 2,
            y: s.origin.y + (s.height - h) / 2,
            width: w,
            height: h
        ))
        ToastWindow.show(message: "Centered", icon: "rectangle.center.inset.filled")
    }

    func maximize() {
        let s = usableScreenFrame()
        moveWindow(to: s)
        ToastWindow.show(message: "Maximized", icon: "rectangle.fill")
    }

    /// Check if accessibility is enabled (no prompt)
    static func checkAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Prompt user for accessibility, then check
    static func promptAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
