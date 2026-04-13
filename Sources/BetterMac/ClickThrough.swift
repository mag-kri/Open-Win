import Cocoa
import ApplicationServices

/// Windows-style click-through: clicking a background window activates it
/// AND passes the click through, so you don't need to click twice.
final class ClickThrough {
    static let shared = ClickThrough()

    private var pollTimer: DispatchSourceTimer?
    private var lastFrontPID: pid_t = 0
    private var enabled = true

    var isEnabled: Bool {
        get { enabled }
        set { enabled = newValue }
    }

    func start() {
        // Track which app is frontmost
        lastFrontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        pollTimer = timer
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
    }

    private func poll() {
        guard enabled else { return }

        let mouseDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        guard mouseDown else {
            // Update frontmost app when mouse is not pressed
            lastFrontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0
            return
        }

        // Mouse just clicked — check if it's on a background window
        // Use CGEvent to get position directly in CG coordinates (avoids
        // coordinate-system conversion issues on multi-monitor setups)
        guard let cgPoint = CGEvent(source: nil)?.location else { return }

        guard let clickedPID = pidOfWindowUnderPoint(cgPoint) else { return }

        // Skip our own app
        if clickedPID == ProcessInfo.processInfo.processIdentifier { return }

        // If clicking on a background app, activate it and resend the click
        if clickedPID != lastFrontPID {
            // Activate the clicked app
            if let app = NSRunningApplication(processIdentifier: clickedPID) {
                app.activate()
            }

            // Resend the click so it goes through to the actual element
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Read current cursor position in CG coordinates at post time
                // to avoid coordinate conversion errors and stale positions
                guard let currentPos = CGEvent(source: nil)?.location else { return }
                let clickDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: currentPos, mouseButton: .left)
                let clickUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: currentPos, mouseButton: .left)
                clickDown?.post(tap: .cghidEventTap)
                clickUp?.post(tap: .cghidEventTap)
            }

            lastFrontPID = clickedPID
        }
    }

    private func pidOfWindowUnderPoint(_ point: CGPoint) -> pid_t? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        for window in windowList {
            guard let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"],
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int else { continue }

            guard layer == 0 else { continue }

            let rect = CGRect(x: x, y: y, width: w, height: h)
            if rect.contains(point) {
                return pid
            }
        }
        return nil
    }
}
