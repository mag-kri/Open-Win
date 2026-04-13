import Cocoa
import ApplicationServices

/// Auto-focuses the window under the mouse cursor (hover-to-focus).
final class FocusFollowsMouse {
    static let shared = FocusFollowsMouse()

    private var pollTimer: DispatchSourceTimer?
    private var lastPID: pid_t = 0
    private var enabled = true
    private var lastFocusTime: TimeInterval = 0

    func start() {
        zlog("[Focus] Starting hover-to-focus")
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100))
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

    var isEnabled: Bool {
        get { enabled }
        set { enabled = newValue }
    }

    private func poll() {
        guard enabled else { return }

        // Don't switch focus while mouse button is held
        if CGEventSource.buttonState(.combinedSessionState, button: .left) { return }

        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: mousePos.x, y: screenHeight - mousePos.y)

        // Find the window under the cursor
        guard let pid = pidOfWindowUnderPoint(cgPoint) else { return }

        // Skip if same app as current
        guard pid != lastPID else { return }

        // Skip our own app
        if pid == ProcessInfo.processInfo.processIdentifier { return }

        // Cooldown
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastFocusTime > 0.15 else { return }

        // Skip if already the frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.processIdentifier == pid {
            lastPID = pid
            return
        }

        lastPID = pid
        lastFocusTime = now

        // Activate the app
        if let app = NSRunningApplication(processIdentifier: pid) {
            zlog("[Focus] Focusing → \(app.localizedName ?? "?") (pid=\(pid))")
            app.activate()
        }
    }

    /// Find the PID of the app that owns the topmost window at the given point.
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

            // Only normal windows (layer 0)
            guard layer == 0 else { continue }

            let rect = CGRect(x: x, y: y, width: w, height: h)
            if rect.contains(point) {
                return pid
            }
        }
        return nil
    }
}
