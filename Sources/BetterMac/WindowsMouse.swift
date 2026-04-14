import Cocoa
import Carbon

/// Windows-style mouse behavior: reverse scroll direction and linear acceleration curve.
final class WindowsMouse {
    static let shared = WindowsMouse()

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    // MARK: - Settings

    var scrollEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "windowsScrollEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "windowsScrollEnabled") }
    }

    var accelEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: "windowsMouseAccelEnabled") }
        set { UserDefaults.standard.set(newValue, forKey: "windowsMouseAccelEnabled") }
    }

    var mouseSpeed: Double {
        get {
            let v = UserDefaults.standard.double(forKey: "windowsMouseSpeed")
            return v == 0 ? 1.0 : v
        }
        set { UserDefaults.standard.set(newValue, forKey: "windowsMouseSpeed") }
    }

    // MARK: - Lifecycle

    func start() {
        guard eventTap == nil else {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }

        let mask: CGEventMask =
            (1 << CGEventType.scrollWheel.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.rightMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let me = Unmanaged<WindowsMouse>.fromOpaque(refcon!).takeUnretainedValue()

                if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                    if let tap = me.eventTap {
                        CGEvent.tapEnable(tap: tap, enable: true)
                    }
                    return Unmanaged.passRetained(event)
                }

                if type == .scrollWheel {
                    me.handleScroll(event)
                } else {
                    me.handleMouseMove(event)
                }

                return Unmanaged.passRetained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            zlog("[WindowsMouse] FAILED to create event tap")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        zlog("[WindowsMouse] Event tap started")
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    // MARK: - Scroll Reversal

    private func handleScroll(_ event: CGEvent) {
        guard scrollEnabled else { return }

        // Reverse line-based delta (discrete scroll)
        let delta1 = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
        let delta2 = event.getIntegerValueField(.scrollWheelEventDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -delta1)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: -delta2)

        // Reverse fixed-point delta (smooth/continuous scroll)
        let fixedPt1 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1)
        let fixedPt2 = event.getDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: -fixedPt1)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: -fixedPt2)

        // Reverse pixel delta (trackpad/high-res scroll)
        let pt1 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
        let pt2 = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis2)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -pt1)
        event.setIntegerValueField(.scrollWheelEventPointDeltaAxis2, value: -pt2)
    }

    // MARK: - Mouse Acceleration (Windows-style linear curve)

    private func handleMouseMove(_ event: CGEvent) {
        guard accelEnabled else { return }

        let speed = mouseSpeed

        // Read the current (accelerated) deltas
        let dx = event.getDoubleValueField(.mouseEventDeltaX)
        let dy = event.getDoubleValueField(.mouseEventDeltaY)

        // Apply Windows-style linear scaling with slight boost at high velocity
        let velocity = sqrt(dx * dx + dy * dy)
        let boost: Double = velocity > 10 ? 1.0 + (velocity - 10) * 0.02 : 1.0
        let factor = speed * min(boost, 2.0)

        event.setDoubleValueField(.mouseEventDeltaX, value: dx * factor)
        event.setDoubleValueField(.mouseEventDeltaY, value: dy * factor)
    }
}
