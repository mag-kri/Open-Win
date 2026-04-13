import Cocoa
import ApplicationServices

/// Focus follows mouse — disabled by default.
/// macOS already supports scrolling in background windows natively.
/// This feature adds keyboard focus following (like X11/Linux), but most
/// users prefer the Windows-style where only click changes focus.
final class FocusFollowsMouse {
    static let shared = FocusFollowsMouse()

    private var pollTimer: DispatchSourceTimer?
    private var lastPID: pid_t = 0
    private var enabled = false // off by default

    func start() {
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

        if CGEventSource.buttonState(.combinedSessionState, button: .left) { return }

        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: mousePos.x, y: screenHeight - mousePos.y)

        guard let pid = pidOfWindowUnderPoint(cgPoint) else { return }
        guard pid != lastPID else { return }
        if pid == ProcessInfo.processInfo.processIdentifier { return }

        if let frontApp = NSWorkspace.shared.frontmostApplication, frontApp.processIdentifier == pid {
            lastPID = pid
            return
        }

        lastPID = pid

        if let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
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
