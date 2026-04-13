import Cocoa
import CoreGraphics

/// Shows zone overlay only when dragging (mouse held + moved) AND Shift is held.
/// Release either mouse or Shift to snap/cancel.
final class DragManager {
    static let shared = DragManager()

    var onShowOverlay: (() -> Void)?
    var onUpdatePosition: ((CGPoint) -> Void)?
    var onSnap: (() -> Void)?

    private var isOverlayShown = false
    private var pollTimer: DispatchSourceTimer?

    private var wasMouseDown = false
    private var dragStartPos = CGPoint.zero
    private var isDragging = false
    private let dragThreshold: CGFloat = 10

    func start() {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(32))
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
        let mouseDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        let shiftDown = CGEventSource.flagsState(.combinedSessionState).contains(.maskShift)
        let mousePos = NSEvent.mouseLocation
        let screenHeight = NSScreen.main?.frame.height ?? 0
        let cgPoint = CGPoint(x: mousePos.x, y: screenHeight - mousePos.y)

        // Track drag start
        if mouseDown && !wasMouseDown {
            dragStartPos = mousePos
            isDragging = false
        }

        // Detect drag (mouse moved enough while held)
        if mouseDown && !isDragging {
            let dx = abs(mousePos.x - dragStartPos.x)
            let dy = abs(mousePos.y - dragStartPos.y)
            if dx > dragThreshold || dy > dragThreshold {
                isDragging = true
            }
        }

        // Show overlay: dragging + Shift held
        if isDragging && shiftDown && !isOverlayShown {
            isOverlayShown = true
            onShowOverlay?()
        }

        // Snap: mouse released while overlay is shown
        if !mouseDown && isOverlayShown {
            isOverlayShown = false
            isDragging = false
            onSnap?()
        }

        // Cancel: Shift released while overlay is shown (but still dragging)
        if !shiftDown && isOverlayShown {
            isOverlayShown = false
            onSnap?()
        }

        if !mouseDown {
            isDragging = false
        }

        // Update hover
        if isOverlayShown {
            onUpdatePosition?(cgPoint)
        }

        wasMouseDown = mouseDown
    }
}
