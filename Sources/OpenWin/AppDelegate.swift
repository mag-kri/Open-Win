import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var overlayWindow: ZoneOverlayWindow?
    private var dragOverlayWindow: ZoneOverlayWindow?
    private var welcomeWindow: WelcomeWindow?
    private var preferencesWindow: PreferencesWindow?
    private let hotkeyManager = HotkeyManager.shared
    private let dragManager = DragManager.shared
    private let focusManager = FocusFollowsMouse.shared
    private let clickThrough = ClickThrough.shared
    private var accessibilityTimer: Timer?
    private var altTabWindow: AltTabWindow?
    private var zoneEditor: ZoneEditor?
    private var windowsFocusItem: NSMenuItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBar()
        requestAccessibilityAndStart()
    }

    private func requestAccessibilityAndStart() {
        if WindowManager.promptAccessibility() {
            zlog("Accessibility: GRANTED")
            startEngine()
        } else {
            zlog("Accessibility: NOT GRANTED — polling silently...")
            accessibilityTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if WindowManager.checkAccessibility() {
                    zlog("Accessibility: NOW GRANTED!")
                    timer.invalidate()
                    self?.accessibilityTimer = nil
                    self?.startEngine()
                }
            }
        }
    }

    private func startEngine() {
        setupHotkeys()
        setupDragManager()
        dragManager.start()
        clickThrough.start()
        ToastWindow.show(message: "OpenWin active", icon: "checkmark.circle.fill")
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "OpenWin")
            button.image?.size = NSSize(width: 18, height: 18)
        }

        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "OpenWin", action: nil, keyEquivalent: "")
        titleItem.attributedTitle = NSAttributedString(
            string: "OpenWin",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .bold)]
        )
        menu.addItem(titleItem)
        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Show Zones       ⌃⌥Z", action: #selector(toggleOverlay), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Edit Zones       ⌃⌥E", action: #selector(openZoneEditor), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Screenshot       ⇧⌥S", action: #selector(showScreenCapture), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())

        let actionsItem = NSMenuItem(title: "Quick Actions", action: nil, keyEquivalent: "")
        let actionsMenu = NSMenu()
        actionsMenu.addItem(NSMenuItem(title: "← Left Half", action: #selector(doLeft), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "→ Right Half", action: #selector(doRight), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "↑ Top Half", action: #selector(doTop), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "↓ Bottom Half", action: #selector(doBottom), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem.separator())
        actionsMenu.addItem(NSMenuItem(title: "◰ Top Left", action: #selector(doTopLeft), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "◳ Top Right", action: #selector(doTopRight), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "◱ Bottom Left", action: #selector(doBottomLeft), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "◲ Bottom Right", action: #selector(doBottomRight), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem.separator())
        actionsMenu.addItem(NSMenuItem(title: "◎ Center", action: #selector(doCenter), keyEquivalent: ""))
        actionsMenu.addItem(NSMenuItem(title: "▣ Maximize", action: #selector(doMaximize), keyEquivalent: ""))
        actionsItem.submenu = actionsMenu
        menu.addItem(actionsItem)

        let shortcutsItem = NSMenuItem(title: "Keyboard Shortcuts", action: nil, keyEquivalent: "")
        let shortcutsMenu = NSMenu()
        let shortcuts = [
            "⇧ Hold    Show zones (drag-snap)",
            "⌃⌥Z      Show zones (overlay)",
            "⌃⌥←      Left Half",
            "⌃⌥→      Right Half",
            "⌃⌥↑      Top Half",
            "⌃⌥↓      Bottom Half",
            "⌃⌥U      Top Left",
            "⌃⌥I      Top Right",
            "⌃⌥J      Bottom Left",
            "⌃⌥K      Bottom Right",
            "⌃⌥C      Center",
            "⌃⌥↵      Maximize",
        ]
        for s in shortcuts {
            let item = NSMenuItem(title: s, action: nil, keyEquivalent: "")
            item.attributedTitle = NSAttributedString(
                string: s,
                attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)]
            )
            shortcutsMenu.addItem(item)
        }
        shortcutsItem.submenu = shortcutsMenu
        menu.addItem(shortcutsItem)

        menu.addItem(NSMenuItem.separator())

        let winFocus = NSMenuItem(title: "Windows-style Focus", action: #selector(toggleWindowsFocus), keyEquivalent: "")
        winFocus.state = .on
        windowsFocusItem = winFocus
        menu.addItem(winFocus)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Accessibility...", action: #selector(openAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit OpenWin", action: #selector(quit), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Hotkeys

    private func setupHotkeys() {
        hotkeyManager.onToggleOverlay = { [weak self] in
            self?.toggleOverlay()
        }
        hotkeyManager.onZoneEditor = { [weak self] in
            self?.openZoneEditor()
        }
        hotkeyManager.onScreenCapture = {
            ScreenCapture.shared.start()
        }
        hotkeyManager.onAltTab = { [weak self] in
            self?.showAltTab()
        }
        hotkeyManager.onAltTabCycle = { [weak self] in
            self?.altTabWindow?.cycleNext()
        }
        hotkeyManager.start()
    }

    // MARK: - Drag Manager

    private func setupDragManager() {
        dragManager.onShowOverlay = { [weak self] in
            self?.showDragOverlay()
        }
        dragManager.onUpdatePosition = { [weak self] point in
            self?.dragOverlayWindow?.updateHoverAt(screenPoint: point)
        }
        dragManager.onSnap = { [weak self] in
            self?.dragOverlayWindow?.snapToHoveredZone()
            self?.dragOverlayWindow = nil
        }
    }

    // MARK: - Overlay

    @objc private func toggleOverlay() {
        if let window = overlayWindow, window.isVisible {
            overlayWindow?.dismiss()
        } else {
            overlayWindow = ZoneOverlayWindow(onZoneSelected: { zone in
                WindowManager.shared.moveToZone(zone)
            })
            overlayWindow?.show()
        }
    }

    private func showDragOverlay() {
        dragOverlayWindow?.dismiss()
        dragOverlayWindow = ZoneOverlayWindow(onZoneSelected: { zone in
            WindowManager.shared.moveToZone(zone)
        }, dragMode: true)
        dragOverlayWindow?.show()
    }

    // MARK: - Windows

    @objc private func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showAltTab() {
        if altTabWindow != nil { return }
        hotkeyManager.altTabActive = true
        altTabWindow = AltTabWindow { [weak self] in
            self?.altTabWindow = nil
            self?.hotkeyManager.altTabActive = false
        }
        altTabWindow?.show()
    }

    @objc private func openZoneEditor() {
        zoneEditor?.dismiss()
        zoneEditor = ZoneEditor(currentZones: ZoneLayout.current.zones) { [weak self] newZones in
            ZoneLayout.current = ZoneLayout(name: "Custom", zones: newZones)
            ToastWindow.show(message: "Zones saved (\(newZones.count))", icon: "rectangle.split.2x2")
            self?.zoneEditor = nil
        }
        zoneEditor?.show()
    }

    @objc private func showScreenCapture() {
        ScreenCapture.shared.start()
    }

    @objc private func toggleWindowsFocus() {
        let newState = !clickThrough.isEnabled
        clickThrough.isEnabled = newState
        windowsFocusItem?.state = newState ? .on : .off
        ToastWindow.show(
            message: newState ? "Windows-style Focus: ON" : "Windows-style Focus: OFF",
            icon: newState ? "cursorarrow.click" : "cursorarrow"
        )
    }

    @objc private func openAccessibility() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    // MARK: - Quick Actions

    @objc private func doLeft() { WindowManager.shared.moveLeft() }
    @objc private func doRight() { WindowManager.shared.moveRight() }
    @objc private func doTop() { WindowManager.shared.moveTop() }
    @objc private func doBottom() { WindowManager.shared.moveBottom() }
    @objc private func doTopLeft() { WindowManager.shared.moveTopLeft() }
    @objc private func doTopRight() { WindowManager.shared.moveTopRight() }
    @objc private func doBottomLeft() { WindowManager.shared.moveBottomLeft() }
    @objc private func doBottomRight() { WindowManager.shared.moveBottomRight() }
    @objc private func doCenter() { WindowManager.shared.moveCenter() }
    @objc private func doMaximize() { WindowManager.shared.maximize() }

    @objc private func quit() {
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }
}
