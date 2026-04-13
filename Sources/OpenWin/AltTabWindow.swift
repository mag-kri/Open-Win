import Cocoa
import ApplicationServices

/// Windows-style Alt+Tab: hold Option, press Tab to cycle, release Option to switch.
/// Shows window thumbnails in a horizontal strip.
final class AltTabWindow: NSWindow {
    private var windows: [WindowEntry] = []
    private var selectedIndex = 0
    private var thumbnailViews: [ThumbnailView] = []
    private var flagsMonitor: Any?
    private var keyMonitor: Any?
    private var optionPollTimer: DispatchSourceTimer?
    private var onDismiss: (() -> Void)?

    struct WindowEntry {
        let pid: pid_t
        let appName: String
        let windowTitle: String
        let appIcon: NSImage
        let windowID: CGWindowID
        let bounds: CGRect
    }

    init(onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss

        guard let screen = NSScreen.main else {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        // Gather all windows
        windows = AltTabWindow.getAllWindows()

        if windows.isEmpty {
            super.init(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
            return
        }

        // Start with second window selected (first is current)
        selectedIndex = windows.count > 1 ? 1 : 0

        // Calculate layout
        let thumbWidth: CGFloat = 180
        let thumbHeight: CGFloat = 130
        let padding: CGFloat = 12
        let maxVisible = min(windows.count, 9)
        let totalWidth = CGFloat(maxVisible) * (thumbWidth + padding) + padding
        let totalHeight = thumbHeight + padding * 2 + 30 // extra for title

        let x = screen.frame.midX - totalWidth / 2
        let y = screen.frame.midY - totalHeight / 2

        super.init(
            contentRect: NSRect(x: x, y: y, width: totalWidth, height: totalHeight),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.collectionBehavior = [.canJoinAllSpaces, .stationary]

        setupContent(thumbWidth: thumbWidth, thumbHeight: thumbHeight, padding: padding, maxVisible: maxVisible)
    }

    private func setupContent(thumbWidth: CGFloat, thumbHeight: CGFloat, padding: CGFloat, maxVisible: Int) {
        let container = NSView(frame: self.contentView!.bounds)
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.92).cgColor
        container.layer?.cornerRadius = 16

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.shadowBlurRadius = 20
        shadow.shadowOffset = NSSize(width: 0, height: -4)
        container.shadow = shadow

        for i in 0..<maxVisible {
            let x = padding + CGFloat(i) * (thumbWidth + padding)
            let thumbView = ThumbnailView(
                frame: NSRect(x: x, y: padding, width: thumbWidth, height: thumbHeight + 26),
                entry: windows[i],
                isSelected: i == selectedIndex
            )
            container.addSubview(thumbView)
            thumbnailViews.append(thumbView)
        }

        self.contentView = container
    }

    func show() {
        guard !windows.isEmpty else { return }

        self.alphaValue = 0
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.1
            self.animator().alphaValue = 1
        }

        // Poll for Option release (event monitors don't reliably deliver flagsChanged)
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + 0.3, repeating: .milliseconds(50))
        timer.setEventHandler { [weak self] in
            let optionDown = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlternate)
            if !optionDown {
                self?.switchToSelected()
            }
        }
        timer.resume()
        optionPollTimer = timer

        // Key monitor: Tab to cycle, backtick/shift-tab to go back
        let handleKey: (NSEvent) -> Void = { [weak self] event in
            guard let self = self else { return }
            if event.keyCode == 48 { // Tab
                if event.modifierFlags.contains(.shift) {
                    self.selectPrevious()
                } else {
                    self.selectNext()
                }
            } else if event.keyCode == 53 { // Escape
                self.dismiss()
            }
        }

        keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handleKey(event)
            return event
        }
    }

    func cycleNext() {
        selectNext()
    }

    private func selectNext() {
        let maxVisible = min(windows.count, 9)
        thumbnailViews[selectedIndex].setSelected(false)
        selectedIndex = (selectedIndex + 1) % maxVisible
        thumbnailViews[selectedIndex].setSelected(true)
    }

    private func selectPrevious() {
        let maxVisible = min(windows.count, 9)
        thumbnailViews[selectedIndex].setSelected(false)
        selectedIndex = (selectedIndex - 1 + maxVisible) % maxVisible
        thumbnailViews[selectedIndex].setSelected(true)
    }

    private func switchToSelected() {
        guard selectedIndex < windows.count else { dismiss(); return }
        let entry = windows[selectedIndex]
        dismiss()

        // Activate the app and raise the window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let app = AXUIElementCreateApplication(entry.pid)
            var windowList: AnyObject?
            if AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowList) == .success,
               let axWindows = windowList as? [AXUIElement] {
                for axWindow in axWindows {
                    AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    break
                }
            }
            if let nsApp = NSRunningApplication(processIdentifier: entry.pid) {
                nsApp.activate()
            }
        }
    }

    func dismiss() {
        optionPollTimer?.cancel(); optionPollTimer = nil
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        self.orderOut(nil)
        onDismiss?()
    }

    override var canBecomeKey: Bool { true }

    // MARK: - Gather windows

    static func getAllWindows() -> [WindowEntry] {
        var entries: [WindowEntry] = []
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return [] }

        var seenPIDs = Set<pid_t>()

        for window in windowList {
            guard let pid = window[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = boundsDict["X"], let y = boundsDict["Y"],
                  let w = boundsDict["Width"], let h = boundsDict["Height"] else { continue }

            // Only normal windows
            guard layer == 0 else { continue }
            // Skip tiny windows (menus, popups)
            guard w > 100 && h > 100 else { continue }
            // One entry per app
            guard !seenPIDs.contains(pid) else { continue }
            // Skip ourselves
            guard pid != ProcessInfo.processInfo.processIdentifier else { continue }

            seenPIDs.insert(pid)

            let appName = window[kCGWindowOwnerName as String] as? String ?? "?"
            let windowTitle = window[kCGWindowName as String] as? String ?? appName

            let icon: NSImage
            if let nsApp = NSRunningApplication(processIdentifier: pid), let appIcon = nsApp.icon {
                icon = appIcon
            } else {
                icon = NSImage(systemSymbolName: "macwindow", accessibilityDescription: nil) ?? NSImage()
            }

            entries.append(WindowEntry(
                pid: pid,
                appName: appName,
                windowTitle: windowTitle,
                appIcon: icon,
                windowID: windowID,
                bounds: CGRect(x: x, y: y, width: w, height: h)
            ))
        }
        return entries
    }
}

// MARK: - Thumbnail View

final class ThumbnailView: NSView {
    private let entry: AltTabWindow.WindowEntry
    private var isSelectedState: Bool
    private var iconView: NSImageView!
    private var nameLabel: NSTextField!

    init(frame: CGRect, entry: AltTabWindow.WindowEntry, isSelected: Bool) {
        self.entry = entry
        self.isSelectedState = isSelected
        super.init(frame: frame)
        wantsLayer = true
        layer?.cornerRadius = 10
        setupSubviews()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupSubviews() {
        // Window thumbnail (capture)
        let thumbRect = NSRect(x: 4, y: 30, width: bounds.width - 8, height: bounds.height - 38)
        let thumbView = NSView(frame: thumbRect)
        thumbView.wantsLayer = true
        thumbView.layer?.cornerRadius = 6
        thumbView.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Try to get window screenshot
        if let image = captureWindow(entry.windowID) {
            let imgView = NSImageView(frame: NSRect(x: 0, y: 0, width: thumbRect.width, height: thumbRect.height))
            imgView.image = image
            imgView.imageScaling = .scaleProportionallyUpOrDown
            thumbView.addSubview(imgView)
        } else {
            // Fallback: big icon
            let bigIcon = NSImageView(frame: NSRect(x: (thumbRect.width - 48) / 2, y: (thumbRect.height - 48) / 2, width: 48, height: 48))
            bigIcon.image = entry.appIcon
            thumbView.addSubview(bigIcon)
        }
        addSubview(thumbView)

        // App icon (small)
        iconView = NSImageView(frame: NSRect(x: 4, y: 6, width: 18, height: 18))
        iconView.image = entry.appIcon
        addSubview(iconView)

        // App name
        nameLabel = NSTextField(frame: NSRect(x: 24, y: 6, width: bounds.width - 28, height: 18))
        nameLabel.stringValue = entry.appName
        nameLabel.font = .systemFont(ofSize: 11, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.isBezeled = false
        nameLabel.isEditable = false
        nameLabel.drawsBackground = false
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)
    }

    func setSelected(_ selected: Bool) {
        isSelectedState = selected
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        if isSelectedState {
            NSColor.systemBlue.withAlphaComponent(0.25).setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10).fill()
            NSColor.systemBlue.withAlphaComponent(0.8).setStroke()
            let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 10, yRadius: 10)
            path.lineWidth = 2
            path.stroke()
        }
    }

    private func captureWindow(_ windowID: CGWindowID) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            [.boundsIgnoreFraming, .bestResolution]
        ) else { return nil }

        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width / 2, height: cgImage.height / 2))
    }
}
