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
    private let keyboardDetector = KeyboardDetector.shared
    private var accessibilityTimer: Timer?
    private var altTabWindow: AltTabWindow?
    private var zoneChooser: ZoneChooser?

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
        keyboardDetector.start()
        ScreenCapture.shared.startGlobalMonitor()
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

        menu.addItem(NSMenuItem(title: "Edit Zones", action: #selector(openZoneEditor), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ","))
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
            ScreenCapture.shared.capture()
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
        dragManager.onShowOverlay = { [weak self] screen in
            self?.showDragOverlay(on: screen)
        }
        dragManager.onScreenChanged = { [weak self] screen in
            self?.showDragOverlay(on: screen)
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

    private func showDragOverlay(on screen: NSScreen) {
        dragOverlayWindow?.dismiss()
        dragOverlayWindow = ZoneOverlayWindow(onZoneSelected: { zone in
            WindowManager.shared.moveToZone(zone)
        }, dragMode: true, screen: screen)
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
        zoneChooser?.dismiss()
        zoneChooser = ZoneChooser { _ in }
        zoneChooser?.show()
    }

    @objc private func showScreenCapture() {
        ScreenCapture.shared.capture()
    }

    @objc private func quit() {
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }
}
