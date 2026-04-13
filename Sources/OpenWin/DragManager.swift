import Cocoa
import CoreGraphics

/// Shows zone overlay only when dragging (mouse held + moved) AND Shift is held.
/// Tracks which screen the cursor is on and shows zones for that screen.
final class DragManager {
    static let shared = DragManager()

    var onShowOverlay: ((NSScreen) -> Void)?
    var onUpdatePosition: ((CGPoint) -> Void)?
    var onSnap: (() -> Void)?
    var onScreenChanged: ((NSScreen) -> Void)?

    private var isOverlayShown = false
    private var pollTimer: DispatchSourceTimer?
    private var currentScreen: NSScreen?

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

    /// Find which screen the mouse is on
    private func screenForMouse(_ cocoaPos: CGPoint) -> NSScreen? {
        for screen in NSScreen.screens {
            if screen.frame.contains(cocoaPos) {
                return screen
            }
        }
        return NSScreen.main
    }

    private func poll() {
        let mouseDown = CGEventSource.buttonState(.combinedSessionState, button: .left)
        let flags = CGEventSource.flagsState(.combinedSessionState)
        let requiredMask = ShortcutManager.shared.dragModifierFlags()
        let activeMods = flags.intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand])
        let shiftOnly = activeMods == requiredMask

        let mousePos = NSEvent.mouseLocation // Cocoa coords (bottom-left)
        let mouseScreen = screenForMouse(mousePos)

        // Convert to CG coords using the screen the cursor is on
        let screenHeight = NSScreen.screens.map { $0.frame.maxY }.max() ?? 0
        let cgPoint = CGPoint(x: mousePos.x, y: screenHeight - mousePos.y)

        // Track drag start
        if mouseDown && !wasMouseDown {
            dragStartPos = mousePos
            isDragging = false
        }

        // Detect drag
        if mouseDown && !isDragging {
            let dx = abs(mousePos.x - dragStartPos.x)
            let dy = abs(mousePos.y - dragStartPos.y)
            if dx > dragThreshold || dy > dragThreshold {
                isDragging = true
            }
        }

        // Show overlay: dragging + Shift held
        if isDragging && shiftOnly && !isOverlayShown {
            isOverlayShown = true
            currentScreen = mouseScreen
            if let screen = mouseScreen {
                onShowOverlay?(screen)
            }
        }

        // Screen changed while overlay is shown — rebuild overlay for new screen
        if isOverlayShown && mouseScreen != currentScreen {
            if let screen = mouseScreen {
                currentScreen = screen
                onScreenChanged?(screen)
            }
        }

        // Snap: mouse released
        if !mouseDown && isOverlayShown {
            isOverlayShown = false
            isDragging = false
            onSnap?()
        }

        // Cancel: Shift released
        if !shiftOnly && isOverlayShown {
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
