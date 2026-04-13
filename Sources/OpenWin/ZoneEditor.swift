import Cocoa

/// PowerToys-style zone editor with monitor preview.
/// Shows a scaled-down representation of your screen where you click to split zones.
final class ZoneEditor: NSWindow {
    private var zones: [EditableZone] = []
    private var splitVertical = true
    private var zoneViews: [EditorZoneView] = []
    private var keyMonitor: Any?
    private var hintLabel: NSTextField!
    private var monitorView: NSView!
    private var monitorLabel: NSTextField!
    private var splitModeLabel: NSTextField!
    private var onSave: (([Zone]) -> Void)?
    private var nextID = 1
    private var splitHistory: [[EditableZone]] = [] // for undo

    struct EditableZone {
        let id: Int
        var rect: CGRect // fraction 0-1
    }

    // Monitor preview dimensions
    private let previewWidth: CGFloat = 640
    private let previewHeight: CGFloat = 400
    private let previewPadding: CGFloat = 20

    init(currentZones: [Zone], onSave: @escaping ([Zone]) -> Void) {
        self.onSave = onSave

        let windowWidth: CGFloat = 700
        let windowHeight: CGFloat = 560

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        self.title = "Zone Editor"
        self.isReleasedWhenClosed = false
        self.center()

        // Convert current zones to editable zones
        if currentZones.isEmpty {
            zones = [EditableZone(id: 0, rect: CGRect(x: 0, y: 0, width: 1, height: 1))]
        } else {
            zones = currentZones.map { z in
                let ez = EditableZone(id: nextID, rect: z.rectFraction)
                nextID += 1
                return ez
            }
        }

        setupUI()
        rebuildZoneViews()
    }

    private func setupUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 560))
        content.wantsLayer = true

        // Title
        let title = makeLabel(text: "Zone Editor", frame: NSRect(x: 24, y: 515, width: 300, height: 28), size: 20, weight: .bold)
        content.addSubview(title)

        // Monitor label (display name + resolution)
        let screen = NSScreen.main!
        let res = "\(Int(screen.frame.width))x\(Int(screen.frame.height))"
        monitorLabel = makeLabel(
            text: "Display: \(screen.localizedName) — \(res)",
            frame: NSRect(x: 24, y: 492, width: 400, height: 20),
            size: 12, weight: .regular, color: .secondaryLabelColor
        )
        content.addSubview(monitorLabel)

        // Monitor preview container (looks like a monitor)
        let monitorFrame = NSRect(
            x: (700 - previewWidth - 20) / 2,
            y: 110,
            width: previewWidth + 20,
            height: previewHeight + 40
        )

        // Monitor bezel
        let bezel = NSView(frame: monitorFrame)
        bezel.wantsLayer = true
        bezel.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        bezel.layer?.cornerRadius = 12
        content.addSubview(bezel)

        // Monitor stand
        let standWidth: CGFloat = 80
        let stand = NSView(frame: NSRect(
            x: (700 - standWidth) / 2,
            y: monitorFrame.origin.y - 20,
            width: standWidth, height: 25
        ))
        stand.wantsLayer = true
        stand.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1).cgColor
        stand.layer?.cornerRadius = 4
        content.addSubview(stand)

        let baseWidth: CGFloat = 120
        let base = NSView(frame: NSRect(
            x: (700 - baseWidth) / 2,
            y: monitorFrame.origin.y - 28,
            width: baseWidth, height: 10
        ))
        base.wantsLayer = true
        base.layer?.backgroundColor = NSColor(white: 0.2, alpha: 1).cgColor
        base.layer?.cornerRadius = 3
        content.addSubview(base)

        // Screen area inside the bezel
        monitorView = NSView(frame: NSRect(
            x: monitorFrame.origin.x + 10,
            y: monitorFrame.origin.y + 10,
            width: previewWidth,
            height: previewHeight
        ))
        monitorView.wantsLayer = true
        monitorView.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
        monitorView.layer?.cornerRadius = 4
        content.addSubview(monitorView)

        // Split mode indicator
        splitModeLabel = makeLabel(
            text: "Split: Vertical ┃",
            frame: NSRect(x: 400, y: 515, width: 280, height: 28),
            size: 14, weight: .medium, color: .systemBlue
        )
        splitModeLabel.alignment = .right
        content.addSubview(splitModeLabel)

        // Preset buttons
        let presetLabel = makeLabel(text: "Presets:", frame: NSRect(x: 24, y: 72, width: 60, height: 18), size: 11, weight: .semibold, color: .secondaryLabelColor)
        content.addSubview(presetLabel)

        let presetNames = ZoneLayout.presets.map { $0.name }
        for (i, name) in presetNames.enumerated() {
            let btn = NSButton(frame: NSRect(x: 85 + i * 100, y: 68, width: 95, height: 24))
            btn.title = name
            btn.bezelStyle = .rounded
            btn.font = .systemFont(ofSize: 10, weight: .medium)
            btn.tag = i
            btn.target = self
            btn.action = #selector(presetSelected(_:))
            content.addSubview(btn)
        }

        // Hint
        hintLabel = makeLabel(
            text: "Click a zone to split  ·  Space: toggle direction  ·  Backspace: undo",
            frame: NSRect(x: 0, y: 48, width: 700, height: 18),
            size: 11, weight: .medium, color: .tertiaryLabelColor
        )
        hintLabel.alignment = .center
        content.addSubview(hintLabel)

        // Buttons
        let btnY: CGFloat = 14
        let saveBtn = NSButton(frame: NSRect(x: 460, y: btnY, width: 100, height: 32))
        saveBtn.title = "Save"
        saveBtn.bezelStyle = .rounded
        saveBtn.wantsLayer = true
        saveBtn.layer?.backgroundColor = NSColor.systemBlue.cgColor
        saveBtn.layer?.cornerRadius = 6
        saveBtn.contentTintColor = .white
        saveBtn.isBordered = false
        saveBtn.font = .systemFont(ofSize: 13, weight: .semibold)
        saveBtn.target = self
        saveBtn.action = #selector(doSave)
        content.addSubview(saveBtn)

        let resetBtn = NSButton(frame: NSRect(x: 350, y: btnY, width: 100, height: 32))
        resetBtn.title = "Reset"
        resetBtn.bezelStyle = .rounded
        resetBtn.target = self
        resetBtn.action = #selector(doReset)
        content.addSubview(resetBtn)

        let cancelBtn = NSButton(frame: NSRect(x: 570, y: btnY, width: 100, height: 32))
        cancelBtn.title = "Cancel"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.target = self
        cancelBtn.action = #selector(doCancel)
        content.addSubview(cancelBtn)

        // Zone count
        let countLabel = makeLabel(
            text: "",
            frame: NSRect(x: 24, y: btnY + 5, width: 200, height: 20),
            size: 12, weight: .medium, color: .secondaryLabelColor
        )
        countLabel.tag = 999
        content.addSubview(countLabel)

        self.contentView = content
    }

    private func makeLabel(text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let label = NSTextField(frame: frame)
        label.stringValue = text
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.isBezeled = false
        label.isEditable = false
        label.drawsBackground = false
        label.isSelectable = false
        return label
    }

    private func updateSplitModeLabel() {
        let symbol = splitVertical ? "┃" : "━"
        let dir = splitVertical ? "Vertical" : "Horizontal"
        splitModeLabel?.stringValue = "Split: \(dir) \(symbol)"
    }

    private func updateZoneCount() {
        if let label = contentView?.viewWithTag(999) as? NSTextField {
            label.stringValue = "\(zones.count) zone\(zones.count == 1 ? "" : "s")"
        }
    }

    private var edgeHandles: [EdgeHandleView] = []

    // MARK: - Zone views on monitor preview

    private func rebuildZoneViews() {
        zoneViews.forEach { $0.removeFromSuperview() }
        zoneViews.removeAll()
        edgeHandles.forEach { $0.removeFromSuperview() }
        edgeHandles.removeAll()

        for zone in zones {
            let viewFrame = CGRect(
                x: zone.rect.origin.x * previewWidth,
                y: zone.rect.origin.y * previewHeight,
                width: zone.rect.width * previewWidth,
                height: zone.rect.height * previewHeight
            ).insetBy(dx: 3, dy: 3)

            let view = EditorZoneView(frame: viewFrame, zoneID: zone.id, splitVertical: splitVertical) { [weak self] id in
                self?.splitZone(id: id)
            }
            monitorView.addSubview(view)
            zoneViews.append(view)
        }

        // Add drag handles on shared edges
        buildEdgeHandles()
        updateZoneCount()
    }

    private func buildEdgeHandles() {
        let threshold: CGFloat = 0.001
        let handleSize: CGFloat = 20 // wide enough to grab easily

        for i in 0..<zones.count {
            for j in (i+1)..<zones.count {
                let a = zones[i].rect
                let b = zones[j].rect

                // Shared vertical edge (a's right = b's left)
                if abs((a.origin.x + a.width) - b.origin.x) < threshold {
                    let overlapY = max(a.origin.y, b.origin.y)
                    let overlapMaxY = min(a.origin.y + a.height, b.origin.y + b.height)
                    if overlapMaxY - overlapY > threshold {
                        let edgeX = (a.origin.x + a.width) * previewWidth
                        let edgeY = overlapY * previewHeight
                        let edgeH = (overlapMaxY - overlapY) * previewHeight

                        let handle = EdgeHandleView(
                            frame: NSRect(x: edgeX - handleSize/2, y: edgeY, width: handleSize, height: edgeH),
                            isVertical: true,
                            onDrag: { [weak self] delta in
                                self?.resizeEdge(leftIdx: i, rightIdx: j, delta: delta / (self?.previewWidth ?? 1), isVertical: true)
                            },
                            onDragEnd: { [weak self] in
                                self?.rebuildZoneViews()
                            }
                        )
                        monitorView.addSubview(handle)
                        edgeHandles.append(handle)
                    }
                }

                // Shared horizontal edge (a's top = b's bottom)
                if abs((a.origin.y + a.height) - b.origin.y) < threshold {
                    let overlapX = max(a.origin.x, b.origin.x)
                    let overlapMaxX = min(a.origin.x + a.width, b.origin.x + b.width)
                    if overlapMaxX - overlapX > threshold {
                        let edgeX = overlapX * previewWidth
                        let edgeY = (a.origin.y + a.height) * previewHeight
                        let edgeW = (overlapMaxX - overlapX) * previewWidth

                        let handle = EdgeHandleView(
                            frame: NSRect(x: edgeX, y: edgeY - handleSize/2, width: edgeW, height: handleSize),
                            isVertical: false,
                            onDrag: { [weak self] delta in
                                self?.resizeEdge(leftIdx: i, rightIdx: j, delta: delta / (self?.previewHeight ?? 1), isVertical: false)
                            },
                            onDragEnd: { [weak self] in
                                self?.rebuildZoneViews()
                            }
                        )
                        monitorView.addSubview(handle)
                        edgeHandles.append(handle)
                    }
                }
            }
        }
    }

    /// Resize two adjacent zones by moving their shared edge
    private func resizeEdge(leftIdx: Int, rightIdx: Int, delta: CGFloat, isVertical: Bool) {
        guard leftIdx < zones.count, rightIdx < zones.count else { return }
        let minSize: CGFloat = 0.05

        var a = zones[leftIdx].rect
        var b = zones[rightIdx].rect

        if isVertical {
            let newAWidth = a.width + delta
            let newBWidth = b.width - delta
            guard newAWidth >= minSize, newBWidth >= minSize else { return }
            a = CGRect(x: a.origin.x, y: a.origin.y, width: newAWidth, height: a.height)
            b = CGRect(x: a.origin.x + newAWidth, y: b.origin.y, width: newBWidth, height: b.height)
        } else {
            let newAHeight = a.height + delta
            let newBHeight = b.height - delta
            guard newAHeight >= minSize, newBHeight >= minSize else { return }
            a = CGRect(x: a.origin.x, y: a.origin.y, width: a.width, height: newAHeight)
            b = CGRect(x: b.origin.x, y: a.origin.y + newAHeight, width: b.width, height: newBHeight)
        }

        zones[leftIdx] = EditableZone(id: zones[leftIdx].id, rect: a)
        zones[rightIdx] = EditableZone(id: zones[rightIdx].id, rect: b)

        // Update zone view frames without rebuilding (keeps drag state alive)
        updateZoneViewFrames()
    }

    /// Update existing view positions without destroying/recreating them
    private func updateZoneViewFrames() {
        for (i, zone) in zones.enumerated() {
            guard i < zoneViews.count else { break }
            let viewFrame = CGRect(
                x: zone.rect.origin.x * previewWidth,
                y: zone.rect.origin.y * previewHeight,
                width: zone.rect.width * previewWidth,
                height: zone.rect.height * previewHeight
            ).insetBy(dx: 3, dy: 3)
            zoneViews[i].frame = viewFrame
        }
    }

    // MARK: - Split logic

    private func splitZone(id: Int) {
        guard let idx = zones.firstIndex(where: { $0.id == id }) else { return }

        // Save state for undo
        splitHistory.append(zones)

        let zone = zones[idx]
        let z1: EditableZone
        let z2: EditableZone

        if splitVertical {
            z1 = EditableZone(id: nextID, rect: CGRect(
                x: zone.rect.origin.x, y: zone.rect.origin.y,
                width: zone.rect.width / 2, height: zone.rect.height
            ))
            nextID += 1
            z2 = EditableZone(id: nextID, rect: CGRect(
                x: zone.rect.origin.x + zone.rect.width / 2, y: zone.rect.origin.y,
                width: zone.rect.width / 2, height: zone.rect.height
            ))
            nextID += 1
        } else {
            z1 = EditableZone(id: nextID, rect: CGRect(
                x: zone.rect.origin.x, y: zone.rect.origin.y,
                width: zone.rect.width, height: zone.rect.height / 2
            ))
            nextID += 1
            z2 = EditableZone(id: nextID, rect: CGRect(
                x: zone.rect.origin.x, y: zone.rect.origin.y + zone.rect.height / 2,
                width: zone.rect.width, height: zone.rect.height / 2
            ))
            nextID += 1
        }

        zones.remove(at: idx)
        zones.insert(z2, at: idx)
        zones.insert(z1, at: idx)
        rebuildZoneViews()
    }

    private func undo() {
        guard let prev = splitHistory.popLast() else { return }
        zones = prev
        rebuildZoneViews()
    }

    // MARK: - Actions

    @objc private func doSave() {
        let result = zones.enumerated().map { (i, ez) in
            Zone(name: "Zone \(i + 1)", number: i + 1, rectFraction: ez.rect)
        }
        dismiss()
        onSave?(result)
    }

    @objc private func presetSelected(_ sender: NSButton) {
        let preset = ZoneLayout.presets[sender.tag]
        splitHistory.append(zones)
        zones = preset.zones.map { z in
            let ez = EditableZone(id: nextID, rect: z.rectFraction)
            nextID += 1
            return ez
        }
        rebuildZoneViews()
    }

    @objc private func doReset() {
        splitHistory.append(zones)
        zones = [EditableZone(id: 0, rect: CGRect(x: 0, y: 0, width: 1, height: 1))]
        nextID = 1
        rebuildZoneViews()
    }

    @objc private func doCancel() {
        dismiss()
    }

    // MARK: - Show/Dismiss

    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 49: // Space
                self.splitVertical.toggle()
                self.updateSplitModeLabel()
                self.zoneViews.forEach { $0.splitVertical = self.splitVertical; $0.needsDisplay = true }
                return nil
            case 36: // Enter
                self.doSave()
                return nil
            case 53: // Escape
                self.doCancel()
                return nil
            case 15: // R
                self.doReset()
                return nil
            case 51: // Backspace
                self.undo()
                return nil
            default:
                return event
            }
        }
    }

    func dismiss() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        self.orderOut(nil)
    }

    override var canBecomeKey: Bool { true }
}

// MARK: - Editor Zone View

final class EditorZoneView: NSView {
    private let zoneID: Int
    var splitVertical: Bool
    private var isHovered = false
    private var onClick: ((Int) -> Void)?

    init(frame: CGRect, zoneID: Int, splitVertical: Bool, onClick: @escaping (Int) -> Void) {
        self.zoneID = zoneID
        self.splitVertical = splitVertical
        self.onClick = onClick
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 6

        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)

        if isHovered {
            NSColor.systemBlue.withAlphaComponent(0.25).setFill()
            NSColor.systemBlue.withAlphaComponent(1.0).setStroke()
            path.lineWidth = 2
        } else {
            NSColor.systemBlue.withAlphaComponent(0.08).setFill()
            NSColor.white.withAlphaComponent(0.3).setStroke()
            path.lineWidth = 1
        }

        path.fill()
        path.stroke()

        // Split preview line when hovered
        if isHovered {
            let dashPattern: [CGFloat] = [5, 3]
            let splitLine = NSBezierPath()
            NSColor.systemBlue.withAlphaComponent(0.9).setStroke()

            if splitVertical {
                splitLine.move(to: NSPoint(x: bounds.midX, y: rect.minY + 6))
                splitLine.line(to: NSPoint(x: bounds.midX, y: rect.maxY - 6))
            } else {
                splitLine.move(to: NSPoint(x: rect.minX + 6, y: bounds.midY))
                splitLine.line(to: NSPoint(x: rect.maxX - 6, y: bounds.midY))
            }
            splitLine.lineWidth = 2
            splitLine.setLineDash(dashPattern, count: 2, phase: 0)
            splitLine.stroke()

            // "Click to split" label
            let label = "Click to split"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.7),
            ]
            let size = label.size(withAttributes: attrs)
            if bounds.width > size.width + 10 && bounds.height > size.height + 10 {
                label.draw(at: CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2 - 14), withAttributes: attrs)
            }
        }
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) { onClick?(zoneID) }
}

// MARK: - Edge Handle View (draggable border between zones)

final class EdgeHandleView: NSView {
    private let isVertical: Bool
    private var onDrag: ((CGFloat) -> Void)?
    private var onDragEnd: (() -> Void)?
    private var lastDragPoint: CGPoint?

    init(frame: CGRect, isVertical: Bool, onDrag: @escaping (CGFloat) -> Void, onDragEnd: @escaping () -> Void = {}) {
        self.isVertical = isVertical
        self.onDrag = onDrag
        self.onDragEnd = onDragEnd
        super.init(frame: frame)
        wantsLayer = true

        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self)
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        // Draw a subtle line
        NSColor.systemBlue.withAlphaComponent(0.4).setFill()
        if isVertical {
            NSRect(x: bounds.midX - 1, y: 0, width: 2, height: bounds.height).fill()
        } else {
            NSRect(x: 0, y: bounds.midY - 1, width: bounds.width, height: 2).fill()
        }
    }

    override func cursorUpdate(with event: NSEvent) {
        if isVertical {
            NSCursor.resizeLeftRight.set()
        } else {
            NSCursor.resizeUpDown.set()
        }
    }

    override func mouseEntered(with event: NSEvent) {
        if isVertical {
            NSCursor.resizeLeftRight.push()
        } else {
            NSCursor.resizeUpDown.push()
        }
    }

    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }

    override func mouseDown(with event: NSEvent) {
        lastDragPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        let current = convert(event.locationInWindow, from: nil)
        guard let last = lastDragPoint else { return }

        let delta: CGFloat
        if isVertical {
            delta = current.x - last.x
        } else {
            delta = current.y - last.y
        }

        lastDragPoint = current
        onDrag?(delta)
    }

    override func mouseUp(with event: NSEvent) {
        lastDragPoint = nil
        onDragEnd?()
    }
}
