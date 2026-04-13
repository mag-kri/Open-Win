import Cocoa

final class ZoneOverlayWindow: NSWindow {
    private var layout: ZoneLayout!
    private var zoneViews: [ZoneView] = []
    private var onZoneSelected: ((Zone) -> Void)?
    private var escMonitor: Any?
    private var isDragMode = false
    private var hoveredZone: Zone?
    private var hintLabel: NSTextField?

    private(set) var targetScreen: NSScreen?

    init(onZoneSelected: @escaping (Zone) -> Void, dragMode: Bool = false, screen: NSScreen? = nil) {
        self.onZoneSelected = onZoneSelected
        self.isDragMode = dragMode

        let screen = screen ?? NSScreen.main
        guard let screen = screen else {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }
        self.targetScreen = screen
        self.layout = ZoneLayout.current(for: screen)

        super.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = NSColor.black.withAlphaComponent(0.3)
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = dragMode // In drag mode, let events pass through
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        setupZoneViews(screenFrame: screen.visibleFrame, fullFrame: screen.frame)
    }

    private func setupZoneViews(screenFrame: CGRect, fullFrame: CGRect) {
        guard let contentView = self.contentView else { return }

        // Title hint at top
        let hint = NSTextField(frame: NSRect(
            x: (fullFrame.width - 400) / 2,
            y: fullFrame.height - 60,
            width: 400, height: 30
        ))
        hint.stringValue = isDragMode
            ? "Drag window to a zone — release to place"
            : "Select a zone — click or press 1-9 · Esc to close"
        hint.font = .systemFont(ofSize: 14, weight: .medium)
        hint.textColor = .white.withAlphaComponent(0.7)
        hint.alignment = .center
        hint.isBezeled = false
        hint.isEditable = false
        hint.drawsBackground = false
        hint.isSelectable = false
        contentView.addSubview(hint)
        hintLabel = hint

        for zone in layout.zones {
            let zoneFrame = zone.frame(for: screenFrame)
            let viewFrame = CGRect(
                x: zoneFrame.origin.x - fullFrame.origin.x,
                y: zoneFrame.origin.y - fullFrame.origin.y,
                width: zoneFrame.width,
                height: zoneFrame.height
            )

            let insetFrame = viewFrame.insetBy(dx: 6, dy: 6)
            let zoneView = ZoneView(frame: insetFrame, zone: zone) { [weak self] selectedZone in
                self?.zoneSelected(selectedZone)
            }
            zoneView.alphaValue = 0
            contentView.addSubview(zoneView)
            zoneViews.append(zoneView)
        }
    }

    // MARK: - Show/Dismiss

    func show() {
        self.alphaValue = 0
        makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.animator().alphaValue = 1.0
        }

        for (i, zoneView) in zoneViews.enumerated() {
            let delay = Double(i) * 0.03
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.25
                    context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                    zoneView.animator().alphaValue = 1.0
                }
            }
        }

        if !isDragMode {
            escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 {
                    self?.dismiss()
                    return nil
                }
                if let char = event.characters, let num = Int(char), num >= 1, num <= 9 {
                    let zones = ZoneLayout.current.zones
                    if let zone = zones.first(where: { $0.number == num }) {
                        self?.zoneSelected(zone)
                    }
                    return nil
                }
                return event
            }
        }
    }

    func dismiss() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
        self.alphaValue = 0
        self.orderOut(nil)
    }

    // MARK: - Drag mode: update highlight based on cursor position

    /// Called during drag — screenPoint is in CG screen coordinates (top-left origin)
    func updateHoverAt(screenPoint: CGPoint) {
        guard let screen = NSScreen.main else { return }
        let fullFrame = screen.frame

        // Convert CG coords (top-left origin) to Cocoa coords (bottom-left origin)
        let cocoaPoint = CGPoint(
            x: screenPoint.x,
            y: fullFrame.height - screenPoint.y
        )

        // Convert to window-local coords
        let windowPoint = CGPoint(
            x: cocoaPoint.x - frame.origin.x,
            y: cocoaPoint.y - frame.origin.y
        )

        var foundZone: Zone? = nil
        for zoneView in zoneViews {
            let isInside = zoneView.frame.contains(windowPoint)
            zoneView.setHovered(isInside)
            if isInside {
                foundZone = zoneView.zone
            }
        }
        if foundZone?.number != hoveredZone?.number {
            zlog("[BetterMac] hover: \(foundZone?.name ?? "none") | cgPt=\(screenPoint) winPt=\(windowPoint)")
        }
        hoveredZone = foundZone
    }

    /// Called when drag ends — snap to hovered zone
    func snapToHoveredZone() {
        let zoneName = hoveredZone?.name ?? "NONE"
        zlog("[BetterMac] snapToHoveredZone: hoveredZone=\(zoneName), zoneViews=\(zoneViews.count)")

        let callback = onZoneSelected
        let zone = hoveredZone

        dismiss()

        if let zone = zone {
            DispatchQueue.main.async {
                callback?(zone)
            }
        }
    }

    private func zoneSelected(_ zone: Zone) {
        if let zoneView = zoneViews.first(where: { $0.zone.number == zone.number }) {
            zoneView.flash()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.onZoneSelected?(zone)
            }
        }
    }

    override var canBecomeKey: Bool { !isDragMode }
}

// MARK: - ZoneView

final class ZoneView: NSView {
    let zone: Zone
    private var isHovered = false
    private var onClick: ((Zone) -> Void)?

    init(frame: CGRect, zone: Zone, onClick: @escaping (Zone) -> Void) {
        self.zone = zone
        self.onClick = onClick
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10

        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    func setHovered(_ hovered: Bool) {
        guard isHovered != hovered else { return }
        isHovered = hovered
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 2, dy: 2)
        let path = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)

        if isHovered {
            NSColor.systemBlue.withAlphaComponent(0.45).setFill()
            NSColor.systemBlue.withAlphaComponent(1.0).setStroke()
            path.lineWidth = 2.5
        } else {
            NSColor.systemBlue.withAlphaComponent(0.12).setFill()
            NSColor.white.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 1.5
        }

        path.fill()
        path.stroke()

        let numberStr = "\(zone.number)"
        let nameStr = zone.name

        let numberAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 32, weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(isHovered ? 1.0 : 0.6),
        ]
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(isHovered ? 0.9 : 0.4),
        ]

        let numSize = numberStr.size(withAttributes: numberAttrs)
        let nameSize = nameStr.size(withAttributes: nameAttrs)
        let totalHeight = numSize.height + nameSize.height + 2

        let numPoint = CGPoint(
            x: (bounds.width - numSize.width) / 2,
            y: (bounds.height - totalHeight) / 2 + nameSize.height + 2
        )
        let namePoint = CGPoint(
            x: (bounds.width - nameSize.width) / 2,
            y: (bounds.height - totalHeight) / 2
        )

        numberStr.draw(at: numPoint, withAttributes: numberAttrs)
        nameStr.draw(at: namePoint, withAttributes: nameAttrs)
    }

    func flash() {
        wantsLayer = true
        let anim = CABasicAnimation(keyPath: "backgroundColor")
        anim.fromValue = NSColor.systemBlue.withAlphaComponent(0.6).cgColor
        anim.toValue = NSColor.white.withAlphaComponent(0.3).cgColor
        anim.duration = 0.12
        layer?.add(anim, forKey: "flash")
    }

    override func mouseEntered(with event: NSEvent) {
        setHovered(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovered(false)
    }

    override func mouseDown(with event: NSEvent) {
        onClick?(zone)
    }
}
