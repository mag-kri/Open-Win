import Cocoa

// MARK: - Zone Chooser (first screen)

/// Shows presets + saved layouts. Click to apply, or "Edit"/"Create New" to open editor.
final class ZoneChooser: NSWindow {
    private var onSave: (([Zone]) -> Void)?
    private var editorWindow: ZoneEditorPanel?
    private var savedContainer: NSView?
    private var activeLabel: NSTextField?
    private var selectedScreen: NSScreen?
    private var screenViews: [NSView] = []

    init(onSave: @escaping ([Zone]) -> Void) {
        self.onSave = onSave

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 580),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "Zone Layouts"
        self.isReleasedWhenClosed = false
        self.center()
        buildUI()
    }

    private func buildUI() {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 580))
        content.wantsLayer = true

        let title = makeLabel(text: "Zone Layouts", frame: NSRect(x: 24, y: 538, width: 300, height: 28), size: 20, weight: .bold)
        content.addSubview(title)

        let subtitle = makeLabel(text: "Choose a layout or create your own", frame: NSRect(x: 24, y: 516, width: 400, height: 18), size: 12, weight: .regular, color: .secondaryLabelColor)
        content.addSubview(subtitle)

        // --- Displays section ---
        let displaysLabel = makeLabel(text: "Displays", frame: NSRect(x: 24, y: 488, width: 200, height: 20), size: 14, weight: .semibold)
        content.addSubview(displaysLabel)

        let screens = NSScreen.screens
        let displayContainer = NSView(frame: NSRect(x: 24, y: 420, width: 572, height: 65))
        displayContainer.wantsLayer = true

        // Find bounds of all screens to scale the preview
        var allBounds = CGRect.zero
        for screen in screens {
            allBounds = allBounds.union(screen.frame)
        }

        let maxPreviewWidth: CGFloat = 572
        let maxPreviewHeight: CGFloat = 55
        let scale = min(maxPreviewWidth / allBounds.width, maxPreviewHeight / allBounds.height) * 0.85

        selectedScreen = NSScreen.main
        screenViews.removeAll()

        for (i, screen) in screens.enumerated() {
            let f = screen.frame
            let x = (f.origin.x - allBounds.origin.x) * scale + (maxPreviewWidth - allBounds.width * scale) / 2
            let y = (f.origin.y - allBounds.origin.y) * scale + (maxPreviewHeight - allBounds.height * scale) / 2
            let w = f.width * scale
            let h = f.height * scale

            let isSelected = (screen == selectedScreen)
            let btn = ScreenButton(
                frame: NSRect(x: x, y: y, width: w, height: h),
                screenIndex: i,
                label: screens.count > 1 ? "\(i + 1)" : screen.localizedName,
                isSelected: isSelected
            ) { [weak self] idx in
                self?.selectScreen(idx)
            }
            btn.toolTip = "\(screen.localizedName) — \(Int(f.width))x\(Int(f.height))\(screen == NSScreen.main ? " (Main)" : "")"
            displayContainer.addSubview(btn)
            screenViews.append(btn)
        }

        content.addSubview(displayContainer)

        // Display count label
        let screenInfo = screens.count == 1
            ? "\(screens[0].localizedName) — \(Int(screens[0].frame.width))x\(Int(screens[0].frame.height))"
            : "\(screens.count) displays connected"
        let infoLabel = makeLabel(text: screenInfo, frame: NSRect(x: 300, y: 488, width: 296, height: 20), size: 11, weight: .regular, color: .secondaryLabelColor)
        infoLabel.alignment = .right
        content.addSubview(infoLabel)

        // Active layout indicator
        let aLabel = makeLabel(text: "Active: \(ZoneLayout.current.name) (\(ZoneLayout.current.zones.count) zones)", frame: NSRect(x: 24, y: 396, width: 400, height: 18), size: 11, weight: .medium, color: .systemBlue)
        activeLabel = aLabel
        content.addSubview(aLabel)

        // Presets section
        let presetsLabel = makeLabel(text: "Presets", frame: NSRect(x: 24, y: 370, width: 200, height: 20), size: 14, weight: .semibold)
        content.addSubview(presetsLabel)

        let presetScroll = NSScrollView(frame: NSRect(x: 24, y: 260, width: 572, height: 110))
        presetScroll.hasHorizontalScroller = true
        presetScroll.hasVerticalScroller = false
        let presetContainer = NSView(frame: NSRect(x: 0, y: 0, width: CGFloat(ZoneLayout.presets.count) * 135, height: 100))
        for (i, preset) in ZoneLayout.presets.enumerated() {
            let card = LayoutCard(
                frame: NSRect(x: i * 135, y: 0, width: 128, height: 100),
                layout: preset,
                onApply: { [weak self] in self?.applyLayout(preset) },
                onEdit: nil
            )
            presetContainer.addSubview(card)
        }
        presetScroll.documentView = presetContainer
        content.addSubview(presetScroll)

        // Saved layouts section
        let savedLabel = makeLabel(text: "My Layouts", frame: NSRect(x: 24, y: 228, width: 200, height: 20), size: 14, weight: .semibold)
        content.addSubview(savedLabel)

        let sContainer = NSView(frame: NSRect(x: 24, y: 70, width: 572, height: 145))
        savedContainer = sContainer
        content.addSubview(sContainer)
        rebuildSavedCards(in: sContainer)

        // Buttons
        let createBtn = NSButton(frame: NSRect(x: 24, y: 20, width: 140, height: 32))
        createBtn.title = "Create New"
        createBtn.bezelStyle = .rounded
        createBtn.wantsLayer = true
        createBtn.layer?.backgroundColor = NSColor.systemBlue.cgColor
        createBtn.layer?.cornerRadius = 6
        createBtn.contentTintColor = .white
        createBtn.isBordered = false
        createBtn.font = .systemFont(ofSize: 13, weight: .semibold)
        createBtn.target = self
        createBtn.action = #selector(createNew)
        content.addSubview(createBtn)

        let previewBtn = NSButton(frame: NSRect(x: 180, y: 20, width: 100, height: 32))
        previewBtn.title = "Preview"
        previewBtn.bezelStyle = .rounded
        previewBtn.target = self
        previewBtn.action = #selector(togglePreview)
        content.addSubview(previewBtn)

        let closeBtn = NSButton(frame: NSRect(x: 500, y: 20, width: 100, height: 32))
        closeBtn.title = "Close"
        closeBtn.bezelStyle = .rounded
        closeBtn.target = self
        closeBtn.action = #selector(doClose)
        content.addSubview(closeBtn)

        self.contentView = content
    }

    private func rebuildSavedCards(in container: NSView) {
        container.subviews.forEach { $0.removeFromSuperview() }
        let saved = ZoneLayout.savedLayouts()

        if saved.isEmpty {
            let empty = makeLabel(text: "No saved layouts yet. Click \"Create New\" to make one.", frame: NSRect(x: 0, y: 60, width: 572, height: 20), size: 12, weight: .regular, color: .tertiaryLabelColor)
            empty.alignment = .center
            container.addSubview(empty)
        } else {
            for (i, layout) in saved.enumerated() {
                let card = LayoutCard(
                    frame: NSRect(x: i * 135, y: 40, width: 128, height: 100),
                    layout: layout,
                    onApply: { [weak self] in self?.applyLayout(layout) },
                    onEdit: { [weak self] in self?.editLayout(layout) }
                )
                container.addSubview(card)

                // Delete button
                let delBtn = NSButton(frame: NSRect(x: i * 135 + 40, y: 5, width: 50, height: 22))
                delBtn.title = "Delete"
                delBtn.bezelStyle = .rounded
                delBtn.font = .systemFont(ofSize: 9)
                delBtn.tag = i
                delBtn.target = self
                delBtn.action = #selector(deleteLayout(_:))
                container.addSubview(delBtn)
            }
        }
    }

    private var flashWindow: NSWindow?
    private var dimWindows: [NSWindow] = []

    private func selectScreen(_ index: Int) {
        let screens = NSScreen.screens
        guard index < screens.count else { return }
        selectedScreen = screens[index]

        // Update screen button highlights
        for (i, view) in screenViews.enumerated() {
            if let btn = view as? ScreenButton {
                btn.setSelected(i == index)
            }
        }
        updateActiveLabel()
    }

    /// Show a persistent blue border on the selected screen, dim others
    private func flashScreen(_ screen: NSScreen) {
        flashWindow?.orderOut(nil)
        dimWindows.forEach { $0.orderOut(nil) }
        dimWindows.removeAll()

        // Blue border on selected screen
        let w = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        w.level = .screenSaver
        w.backgroundColor = .clear
        w.isOpaque = false
        w.ignoresMouseEvents = true
        w.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let border = NSView(frame: w.contentView!.bounds)
        border.wantsLayer = true
        border.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.8).cgColor
        border.layer?.borderWidth = 6
        border.layer?.cornerRadius = 8
        w.contentView?.addSubview(border)

        // Draw current zones on the selected screen
        let layout = ZoneLayout.current(for: screen)
        let visibleFrame = screen.visibleFrame
        let fullFrame = screen.frame

        for zone in layout.zones {
            let zoneFrame = zone.frame(for: visibleFrame)
            let viewFrame = CGRect(
                x: zoneFrame.origin.x - fullFrame.origin.x,
                y: zoneFrame.origin.y - fullFrame.origin.y,
                width: zoneFrame.width,
                height: zoneFrame.height
            ).insetBy(dx: 4, dy: 4)

            let zoneView = NSView(frame: viewFrame)
            zoneView.wantsLayer = true
            zoneView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.08).cgColor
            zoneView.layer?.borderColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            zoneView.layer?.borderWidth = 1.5
            zoneView.layer?.cornerRadius = 6

            // Zone label
            let label = NSTextField(frame: NSRect(x: 0, y: (viewFrame.height - 20) / 2, width: viewFrame.width, height: 20))
            label.stringValue = zone.name
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.textColor = NSColor.white.withAlphaComponent(0.5)
            label.alignment = .center
            label.isBezeled = false
            label.isEditable = false
            label.drawsBackground = false
            zoneView.addSubview(label)

            w.contentView?.addSubview(zoneView)
        }

        // Layout name at top of screen
        let nameLabel = NSTextField(frame: NSRect(x: 0, y: fullFrame.height - 50, width: fullFrame.width, height: 30))
        nameLabel.stringValue = "\(layout.name) (\(layout.zones.count) zones)"
        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.textColor = NSColor.white.withAlphaComponent(0.6)
        nameLabel.alignment = .center
        nameLabel.isBezeled = false
        nameLabel.isEditable = false
        nameLabel.drawsBackground = false
        w.contentView?.addSubview(nameLabel)

        w.alphaValue = 0
        w.orderFront(nil)
        flashWindow = w

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            w.animator().alphaValue = 1
        }

        // Dim all other screens
        for otherScreen in NSScreen.screens where otherScreen != screen {
            let dim = NSWindow(
                contentRect: otherScreen.frame,
                styleMask: .borderless,
                backing: .buffered,
                defer: false
            )
            dim.level = .screenSaver
            dim.backgroundColor = NSColor.black.withAlphaComponent(0.5)
            dim.isOpaque = false
            dim.ignoresMouseEvents = true
            dim.collectionBehavior = [.canJoinAllSpaces, .stationary]

            dim.alphaValue = 0
            dim.orderFront(nil)
            dimWindows.append(dim)

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                dim.animator().alphaValue = 1
            }
        }
    }

    private func applyLayout(_ layout: ZoneLayout) {
        ZoneLayout.setCurrent(layout, for: selectedScreen)
        let screenName = selectedScreen?.localizedName ?? "Main"
        ToastWindow.show(message: "Applied: \(layout.name) → \(screenName)", icon: "rectangle.split.2x2")
        updateActiveLabel()
        onSave?(layout.zones)
    }

    private func editLayout(_ layout: ZoneLayout) {
        editorWindow = ZoneEditorPanel(
            zones: layout.zones,
            name: layout.name
        ) { [weak self] newZones, name in
            let newLayout = ZoneLayout(name: name, zones: newZones)
            ZoneLayout.saveCustomLayout(newLayout)
            ZoneLayout.current = newLayout
            self?.refreshSaved()
            self?.updateActiveLabel()
            self?.onSave?(newZones)
        }
        editorWindow?.show()
    }

    @objc private func createNew() {
        editorWindow = ZoneEditorPanel(
            zones: [],
            name: ""
        ) { [weak self] newZones, name in
            let newLayout = ZoneLayout(name: name, zones: newZones)
            ZoneLayout.saveCustomLayout(newLayout)
            ZoneLayout.current = newLayout
            self?.refreshSaved()
            self?.updateActiveLabel()
            self?.onSave?(newZones)
        }
        editorWindow?.show()
    }

    @objc private func deleteLayout(_ sender: NSButton) {
        let saved = ZoneLayout.savedLayouts()
        guard sender.tag < saved.count else { return }
        ZoneLayout.deleteCustomLayout(name: saved[sender.tag].name)
        refreshSaved()
    }

    private var isPreviewing = false
    private var previewKeyMonitor: Any?

    @objc private func togglePreview() {
        if isPreviewing {
            hidePreview()
        } else {
            showPreview()
        }
    }

    private func showPreview() {
        guard let screen = selectedScreen else { return }
        isPreviewing = true
        flashScreen(screen)

        // Escape to close preview
        previewKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                self?.hidePreview()
                return nil
            }
            return event
        }
    }

    private func hidePreview() {
        isPreviewing = false
        flashWindow?.orderOut(nil)
        flashWindow = nil
        dimWindows.forEach { $0.orderOut(nil) }
        dimWindows.removeAll()
        if let m = previewKeyMonitor { NSEvent.removeMonitor(m); previewKeyMonitor = nil }
    }

    @objc private func doClose() { dismiss() }

    private func refreshSaved() {
        guard let container = savedContainer else { return }
        rebuildSavedCards(in: container)
    }

    private func updateActiveLabel() {
        let layout = ZoneLayout.current(for: selectedScreen)
        let screenName = selectedScreen?.localizedName ?? "Main"
        activeLabel?.stringValue = "Active on \(screenName): \(layout.name) (\(layout.zones.count) zones)"
    }

    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func dismiss() {
        flashWindow?.orderOut(nil)
        flashWindow = nil
        dimWindows.forEach { $0.orderOut(nil) }
        dimWindows.removeAll()
        orderOut(nil)
    }

    private func makeLabel(text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(frame: frame)
        l.stringValue = text; l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color; l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        return l
    }
}

// MARK: - Layout Card (mini preview)

final class LayoutCard: NSView {
    private let layout: ZoneLayout
    private var onApply: (() -> Void)?
    private var onEdit: (() -> Void)?
    private var isHovered = false

    init(frame: CGRect, layout: ZoneLayout, onApply: (() -> Void)?, onEdit: (() -> Void)?) {
        self.layout = layout
        self.onApply = onApply
        self.onEdit = onEdit
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 8

        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let bg = isHovered ? NSColor.systemBlue.withAlphaComponent(0.15) : NSColor.controlBackgroundColor
        bg.setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        path.fill()

        let border = isHovered ? NSColor.systemBlue.withAlphaComponent(0.6) : NSColor.separatorColor
        border.setStroke()
        path.lineWidth = 1
        path.stroke()

        // Draw mini zone preview
        let previewRect = NSRect(x: 8, y: 28, width: bounds.width - 16, height: bounds.height - 48)
        for zone in layout.zones {
            let zr = NSRect(
                x: previewRect.origin.x + zone.rectFraction.origin.x * previewRect.width,
                y: previewRect.origin.y + zone.rectFraction.origin.y * previewRect.height,
                width: zone.rectFraction.width * previewRect.width,
                height: zone.rectFraction.height * previewRect.height
            ).insetBy(dx: 1, dy: 1)
            let zonePath = NSBezierPath(roundedRect: zr, xRadius: 3, yRadius: 3)
            NSColor.systemBlue.withAlphaComponent(isHovered ? 0.2 : 0.1).setFill()
            zonePath.fill()
            NSColor.systemBlue.withAlphaComponent(isHovered ? 0.6 : 0.3).setStroke()
            zonePath.lineWidth = 0.5
            zonePath.stroke()
        }

        // Name
        let nameAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let nameSize = layout.name.size(withAttributes: nameAttrs)
        layout.name.draw(at: CGPoint(x: (bounds.width - nameSize.width) / 2, y: 10), withAttributes: nameAttrs)

        // Zone count
        let countStr = "\(layout.zones.count)"
        let countAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let countSize = countStr.size(withAttributes: countAttrs)
        countStr.draw(at: CGPoint(x: (bounds.width - countSize.width) / 2, y: 1), withAttributes: countAttrs)
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2, onEdit != nil {
            onEdit?()
        } else {
            onApply?()
        }
    }
}

// MARK: - Zone Editor Panel (edit mode)

final class ZoneEditorPanel: NSWindow {
    private var zones: [EditableZone] = []
    private var splitVertical = true
    private var zoneViews: [EditorZoneView] = []
    private var keyMonitor: Any?
    private var monitorView: NSView!
    private var splitModeLabel: NSTextField!
    private var nameField: NSTextField!
    private var onSave: (([Zone], String) -> Void)?
    private var nextID = 1
    private var splitHistory: [[EditableZone]] = []
    private var edgeHandles: [EdgeHandleView] = []

    struct EditableZone {
        let id: Int
        var rect: CGRect
    }

    private let previewWidth: CGFloat = 580
    private let previewHeight: CGFloat = 360

    init(zones inputZones: [Zone], name: String, onSave: @escaping ([Zone], String) -> Void) {
        self.onSave = onSave

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 540),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = name.isEmpty ? "New Layout" : "Edit: \(name)"
        self.isReleasedWhenClosed = false
        self.center()

        if inputZones.isEmpty {
            zones = [EditableZone(id: 0, rect: CGRect(x: 0, y: 0, width: 1, height: 1))]
        } else {
            zones = inputZones.map { z in
                let ez = EditableZone(id: nextID, rect: z.rectFraction)
                nextID += 1
                return ez
            }
        }

        setupUI(name: name)
        rebuildZoneViews()
    }

    private func setupUI(name: String) {
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 540))
        content.wantsLayer = true

        // Name field
        let nameLabel = makeLabel(text: "Name:", frame: NSRect(x: 20, y: 508, width: 45, height: 20), size: 12, weight: .medium)
        content.addSubview(nameLabel)

        nameField = NSTextField(frame: NSRect(x: 68, y: 506, width: 200, height: 24))
        nameField.stringValue = name
        nameField.placeholderString = "My Layout"
        nameField.font = .systemFont(ofSize: 12)
        nameField.bezelStyle = .roundedBezel
        content.addSubview(nameField)

        // Split mode
        splitModeLabel = makeLabel(text: "Split: Vertical ┃", frame: NSRect(x: 400, y: 508, width: 220, height: 20), size: 13, weight: .medium, color: .systemBlue)
        splitModeLabel.alignment = .right
        content.addSubview(splitModeLabel)

        // Monitor bezel
        let bezelFrame = NSRect(x: (640 - previewWidth - 16) / 2, y: 90, width: previewWidth + 16, height: previewHeight + 16)
        let bezel = NSView(frame: bezelFrame)
        bezel.wantsLayer = true
        bezel.layer?.backgroundColor = NSColor(white: 0.15, alpha: 1).cgColor
        bezel.layer?.cornerRadius = 10
        content.addSubview(bezel)

        monitorView = NSView(frame: NSRect(x: bezelFrame.origin.x + 8, y: bezelFrame.origin.y + 8, width: previewWidth, height: previewHeight))
        monitorView.wantsLayer = true
        monitorView.layer?.backgroundColor = NSColor(white: 0.08, alpha: 1).cgColor
        monitorView.layer?.cornerRadius = 4
        content.addSubview(monitorView)

        // Hint
        let hint = makeLabel(text: "Click to split  ·  Space: direction  ·  Backspace: undo", frame: NSRect(x: 0, y: 65, width: 640, height: 16), size: 10, weight: .medium, color: .tertiaryLabelColor)
        hint.alignment = .center
        content.addSubview(hint)

        // Presets row
        let presetLabel = makeLabel(text: "Presets:", frame: NSRect(x: 20, y: 38, width: 55, height: 16), size: 10, weight: .semibold, color: .secondaryLabelColor)
        content.addSubview(presetLabel)
        for (i, preset) in ZoneLayout.presets.enumerated() {
            let btn = NSButton(frame: NSRect(x: 76 + i * 88, y: 34, width: 84, height: 22))
            btn.title = preset.name
            btn.bezelStyle = .rounded
            btn.font = .systemFont(ofSize: 9, weight: .medium)
            btn.tag = i
            btn.target = self
            btn.action = #selector(presetSelected(_:))
            content.addSubview(btn)
        }

        // Buttons
        let saveBtn = NSButton(frame: NSRect(x: 420, y: 4, width: 100, height: 28))
        saveBtn.title = "Save"
        saveBtn.bezelStyle = .rounded
        saveBtn.wantsLayer = true
        saveBtn.layer?.backgroundColor = NSColor.systemBlue.cgColor
        saveBtn.layer?.cornerRadius = 6
        saveBtn.contentTintColor = .white
        saveBtn.isBordered = false
        saveBtn.font = .systemFont(ofSize: 12, weight: .semibold)
        saveBtn.target = self
        saveBtn.action = #selector(doSave)
        content.addSubview(saveBtn)

        let cancelBtn = NSButton(frame: NSRect(x: 530, y: 4, width: 90, height: 28))
        cancelBtn.title = "Cancel"
        cancelBtn.bezelStyle = .rounded
        cancelBtn.target = self
        cancelBtn.action = #selector(doCancel)
        content.addSubview(cancelBtn)

        // Zone count
        let countLabel = makeLabel(text: "", frame: NSRect(x: 20, y: 8, width: 150, height: 16), size: 11, weight: .medium, color: .secondaryLabelColor)
        countLabel.tag = 999
        content.addSubview(countLabel)

        self.contentView = content
    }

    // MARK: - Zone views

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
        buildEdgeHandles()
        updateZoneCount()
    }

    private func buildEdgeHandles() {
        let threshold: CGFloat = 0.001
        let handleSize: CGFloat = 20

        for i in 0..<zones.count {
            for j in (i+1)..<zones.count {
                let a = zones[i].rect
                let b = zones[j].rect

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
                            onDragEnd: { [weak self] in self?.rebuildZoneViews() }
                        )
                        monitorView.addSubview(handle)
                        edgeHandles.append(handle)
                    }
                }

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
                            onDragEnd: { [weak self] in self?.rebuildZoneViews() }
                        )
                        monitorView.addSubview(handle)
                        edgeHandles.append(handle)
                    }
                }
            }
        }
    }

    private func resizeEdge(leftIdx: Int, rightIdx: Int, delta: CGFloat, isVertical: Bool) {
        guard leftIdx < zones.count, rightIdx < zones.count else { return }
        let minSize: CGFloat = 0.05
        var a = zones[leftIdx].rect
        var b = zones[rightIdx].rect

        if isVertical {
            let nw1 = a.width + delta, nw2 = b.width - delta
            guard nw1 >= minSize, nw2 >= minSize else { return }
            a = CGRect(x: a.origin.x, y: a.origin.y, width: nw1, height: a.height)
            b = CGRect(x: a.origin.x + nw1, y: b.origin.y, width: nw2, height: b.height)
        } else {
            let nh1 = a.height + delta, nh2 = b.height - delta
            guard nh1 >= minSize, nh2 >= minSize else { return }
            a = CGRect(x: a.origin.x, y: a.origin.y, width: a.width, height: nh1)
            b = CGRect(x: b.origin.x, y: a.origin.y + nh1, width: b.width, height: nh2)
        }

        zones[leftIdx] = EditableZone(id: zones[leftIdx].id, rect: a)
        zones[rightIdx] = EditableZone(id: zones[rightIdx].id, rect: b)
        updateZoneViewFrames()
    }

    private func updateZoneViewFrames() {
        for (i, zone) in zones.enumerated() {
            guard i < zoneViews.count else { break }
            zoneViews[i].frame = CGRect(
                x: zone.rect.origin.x * previewWidth,
                y: zone.rect.origin.y * previewHeight,
                width: zone.rect.width * previewWidth,
                height: zone.rect.height * previewHeight
            ).insetBy(dx: 3, dy: 3)
        }
    }

    private func updateZoneCount() {
        if let l = contentView?.viewWithTag(999) as? NSTextField {
            l.stringValue = "\(zones.count) zone\(zones.count == 1 ? "" : "s")"
        }
    }

    // MARK: - Split

    private func splitZone(id: Int) {
        guard let idx = zones.firstIndex(where: { $0.id == id }) else { return }
        splitHistory.append(zones)
        let zone = zones[idx]
        let z1: EditableZone, z2: EditableZone

        if splitVertical {
            z1 = EditableZone(id: nextID, rect: CGRect(x: zone.rect.origin.x, y: zone.rect.origin.y, width: zone.rect.width / 2, height: zone.rect.height))
            nextID += 1
            z2 = EditableZone(id: nextID, rect: CGRect(x: zone.rect.origin.x + zone.rect.width / 2, y: zone.rect.origin.y, width: zone.rect.width / 2, height: zone.rect.height))
            nextID += 1
        } else {
            z1 = EditableZone(id: nextID, rect: CGRect(x: zone.rect.origin.x, y: zone.rect.origin.y, width: zone.rect.width, height: zone.rect.height / 2))
            nextID += 1
            z2 = EditableZone(id: nextID, rect: CGRect(x: zone.rect.origin.x, y: zone.rect.origin.y + zone.rect.height / 2, width: zone.rect.width, height: zone.rect.height / 2))
            nextID += 1
        }

        zones.remove(at: idx)
        zones.insert(z2, at: idx)
        zones.insert(z1, at: idx)
        rebuildZoneViews()
    }

    // MARK: - Actions

    @objc private func presetSelected(_ sender: NSButton) {
        let preset = ZoneLayout.presets[sender.tag]
        splitHistory.append(zones)
        zones = preset.zones.map { z in
            let ez = EditableZone(id: nextID, rect: z.rectFraction); nextID += 1; return ez
        }
        rebuildZoneViews()
    }

    @objc private func doSave() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else {
            nameField.becomeFirstResponder()
            NSSound.beep()
            return
        }
        let result = zones.enumerated().map { (i, ez) in
            Zone(name: "Zone \(i + 1)", number: i + 1, rectFraction: ez.rect)
        }
        dismiss()
        onSave?(result, name)
    }

    @objc private func doCancel() { dismiss() }

    // MARK: - Show/Dismiss

    func show() {
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            switch event.keyCode {
            case 49: // Space
                self.splitVertical.toggle()
                let sym = self.splitVertical ? "┃" : "━"
                let dir = self.splitVertical ? "Vertical" : "Horizontal"
                self.splitModeLabel?.stringValue = "Split: \(dir) \(sym)"
                self.zoneViews.forEach { $0.splitVertical = self.splitVertical; $0.needsDisplay = true }
                return nil
            case 36: self.doSave(); return nil
            case 53: self.doCancel(); return nil
            case 51: // Backspace
                if let prev = self.splitHistory.popLast() { self.zones = prev; self.rebuildZoneViews() }
                return nil
            default: return event
            }
        }
    }

    func dismiss() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        orderOut(nil)
    }

    override var canBecomeKey: Bool { true }

    private func makeLabel(text: String, frame: NSRect, size: CGFloat, weight: NSFont.Weight, color: NSColor = .labelColor) -> NSTextField {
        let l = NSTextField(frame: frame)
        l.stringValue = text; l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = color; l.isBezeled = false; l.isEditable = false; l.drawsBackground = false
        return l
    }
}

// MARK: - Screen Button (clickable display in chooser)

final class ScreenButton: NSView {
    private let screenIndex: Int
    private var isSelectedState: Bool
    private var onClick: ((Int) -> Void)?
    private let label: String

    init(frame: CGRect, screenIndex: Int, label: String, isSelected: Bool, onClick: @escaping (Int) -> Void) {
        self.screenIndex = screenIndex
        self.label = label
        self.isSelectedState = isSelected
        self.onClick = onClick
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 4
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
        updateAppearance()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSelected(_ selected: Bool) {
        isSelectedState = selected
        updateAppearance()
    }

    private func updateAppearance() {
        layer?.backgroundColor = (isSelectedState ? NSColor.systemBlue.withAlphaComponent(0.25) : NSColor.systemGray.withAlphaComponent(0.15)).cgColor
        layer?.borderColor = (isSelectedState ? NSColor.systemBlue.withAlphaComponent(0.8) : NSColor.systemGray.withAlphaComponent(0.4)).cgColor
        layer?.borderWidth = isSelectedState ? 2.5 : 1.5

        // Update label
        subviews.forEach { $0.removeFromSuperview() }
        let l = NSTextField(frame: NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height))
        l.stringValue = label
        l.font = .systemFont(ofSize: min(bounds.width * 0.15, 11), weight: .semibold)
        l.textColor = isSelectedState ? .systemBlue : .secondaryLabelColor
        l.alignment = .center
        l.isBezeled = false
        l.isEditable = false
        l.drawsBackground = false
        addSubview(l)
    }

    override func cursorUpdate(with event: NSEvent) { NSCursor.pointingHand.set() }
    override func mouseDown(with event: NSEvent) { onClick?(screenIndex) }
}

// MARK: - Editor Zone View

final class EditorZoneView: NSView {
    private let zoneID: Int
    var splitVertical: Bool
    private var isHovered = false
    private var onClick: ((Int) -> Void)?

    init(frame: CGRect, zoneID: Int, splitVertical: Bool, onClick: @escaping (Int) -> Void) {
        self.zoneID = zoneID; self.splitVertical = splitVertical; self.onClick = onClick
        super.init(frame: frame); wantsLayer = true; layer?.cornerRadius = 6
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let rect = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: rect, xRadius: 6, yRadius: 6)
        (isHovered ? NSColor.systemBlue.withAlphaComponent(0.25) : NSColor.systemBlue.withAlphaComponent(0.08)).setFill()
        (isHovered ? NSColor.systemBlue.withAlphaComponent(1.0) : NSColor.white.withAlphaComponent(0.3)).setStroke()
        path.lineWidth = isHovered ? 2 : 1; path.fill(); path.stroke()

        if isHovered {
            let dash: [CGFloat] = [5, 3]; let line = NSBezierPath()
            NSColor.systemBlue.withAlphaComponent(0.9).setStroke()
            if splitVertical {
                line.move(to: NSPoint(x: bounds.midX, y: rect.minY + 6)); line.line(to: NSPoint(x: bounds.midX, y: rect.maxY - 6))
            } else {
                line.move(to: NSPoint(x: rect.minX + 6, y: bounds.midY)); line.line(to: NSPoint(x: rect.maxX - 6, y: bounds.midY))
            }
            line.lineWidth = 2; line.setLineDash(dash, count: 2, phase: 0); line.stroke()

            let label = "Click to split"
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .medium), .foregroundColor: NSColor.white.withAlphaComponent(0.7)]
            let sz = label.size(withAttributes: attrs)
            if bounds.width > sz.width + 10 && bounds.height > sz.height + 10 {
                label.draw(at: CGPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2 - 14), withAttributes: attrs)
            }
        }
    }
    override func mouseEntered(with event: NSEvent) { isHovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { isHovered = false; needsDisplay = true }
    override func mouseDown(with event: NSEvent) { onClick?(zoneID) }
}

// MARK: - Edge Handle View

final class EdgeHandleView: NSView {
    private let isVertical: Bool
    private var onDrag: ((CGFloat) -> Void)?
    private var onDragEnd: (() -> Void)?
    private var lastDragPoint: CGPoint?

    init(frame: CGRect, isVertical: Bool, onDrag: @escaping (CGFloat) -> Void, onDragEnd: @escaping () -> Void = {}) {
        self.isVertical = isVertical; self.onDrag = onDrag; self.onDragEnd = onDragEnd
        super.init(frame: frame); wantsLayer = true
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect, .cursorUpdate], owner: self))
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.systemBlue.withAlphaComponent(0.4).setFill()
        if isVertical { NSRect(x: bounds.midX - 1, y: 0, width: 2, height: bounds.height).fill() }
        else { NSRect(x: 0, y: bounds.midY - 1, width: bounds.width, height: 2).fill() }
    }
    override func cursorUpdate(with event: NSEvent) { (isVertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).set() }
    override func mouseEntered(with event: NSEvent) { (isVertical ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push() }
    override func mouseExited(with event: NSEvent) { NSCursor.pop() }
    override func mouseDown(with event: NSEvent) { lastDragPoint = convert(event.locationInWindow, from: nil) }
    override func mouseDragged(with event: NSEvent) {
        let cur = convert(event.locationInWindow, from: nil)
        guard let last = lastDragPoint else { return }
        onDrag?(isVertical ? cur.x - last.x : cur.y - last.y); lastDragPoint = cur
    }
    override func mouseUp(with event: NSEvent) { lastDragPoint = nil; onDragEnd?() }
}
