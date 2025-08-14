////
//  AppDelegate.swift
//  DesmosPopUp
//
//  Created by Oori Schubert on 1/18/25.
//

import Cocoa
import Carbon.HIToolbox
import WebKit

// MARK: - Carbon constants (if not in bridging header)
public let kEventParamNameHotKeyID: UInt32 = 0x686B6964  // 'hkid'
public let typeEventHotKeyID: UInt32      = 0x686B6964   // 'hkid'
public let kEventClassKeyboard: UInt32    = 0x6B657962   // 'keyb'
public let kEventHotKeyPressed: UInt32    = 6
public let kVK_ANSI_D: Int32              = 2
public let kVK_Escape: UInt16             = 53

// (2) Define the callback as a top-level C function
//     In 64-bit, we do not need NewEventHandlerUPP.

func HotKeyHandlerCallback(
    callRef: EventHandlerCallRef?,
    eventRef: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
#if DEBUG
    print("HotKeyHandlerCallback triggered!")
#endif
    // Extract the hotkey ID (optional — left blank; we register only one ID = 0)
    let hkID = EventHotKeyID()
    // If it matches our ID, toggle the Desmos window
    if hkID.id == 0, let userData = userData {  //changed from 1
        let mySelf = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        mySelf.toggleDesmosWindow()
    }
    return noErr
}

@objc class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - WebViews & UI elements
    // Keep a reference to the webview to easily load new URLs.
    var desmosWebView: WKWebView?
    // Pre‑loaded webviews for each calculator
    var matrixWebView: WKWebView!
    var graphingWebView: WKWebView!
    var scientificWebView: WKWebView!

    // Buttons to indicate which Desmos calculator is active
    var matrixButton: NSButton!
    var graphingButton: NSButton!
    var scientificButton: NSButton!

    @objc private func loadMatrix() {
        switchTo(matrixWebView)
        updateSelection(matrixButton)
        updateStatusMenuSelection()
    }

    @objc private func loadGraphing() {
        switchTo(graphingWebView)
        updateSelection(graphingButton)
        updateStatusMenuSelection()
    }
    
    @objc private func loadScientific() {
        switchTo(scientificWebView)
        updateSelection(scientificButton)
        updateStatusMenuSelection()
    }

    // MARK: - Window / Status Item

    var desmosWindowController: NSWindowController?
    var statusItem: NSStatusItem?
    var isStatusItemVisible = true

    // Status-menu items (to reflect selection style)
    private var statusScientificItem: NSMenuItem?
    private var statusGraphingItem: NSMenuItem?
    private var statusAlgebraItem: NSMenuItem?

    // MARK: - Hotkey (state, persistence)
    var hotKeyRef: EventHotKeyRef?
    var currentHotKeyCode: UInt32 = UInt32(kVK_ANSI_D)          // default: D
    var currentHotKeyModifiers: UInt32 = UInt32(optionKey)      // default: ⌥
    var currentHotKeyDisplay: String = "⌥D"                     // user-visible text
    var hotkeyCaptureMonitor: Any?
    var hotKeyHandlerInstalled = false
    // --- Persistence keys ---
    private let defaultsKeyHotKeyCode = "DesmosHotkeyKeyCode"
    private let defaultsKeyHotKeyMods = "DesmosHotkeyModifiers"
    private let defaultsKeyHotKeyDisplay = "DesmosHotkeyDisplay"

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupDesmosWindow()
        loadHotkeyFromDefaults()
        registerGlobalHotKey()
        setupStatusItem()
    }

    func setupDesmosWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Desmos"
        // Prevent window from being resized below a minimum size
        window.minSize = NSSize(width: 225, height: 400)
        // Make the window itself transparent so vibrancy shines through
        window.isOpaque = false
        window.backgroundColor = .clear

        let contentBounds = window.contentView!.bounds
        // ---------- Frosted blur background ----------
        let blurView = NSVisualEffectView(frame: contentBounds)
        blurView.autoresizingMask = [.width, .height]
        blurView.material = .sidebar          // pick the material you prefer
        blurView.blendingMode = .behindWindow
        blurView.state = .active
        window.contentView?.addSubview(blurView)

        matrixWebView = WKWebView(frame: contentBounds)
        matrixWebView.setValue(false, forKey: "drawsBackground")  // transparency
        graphingWebView = WKWebView(frame: contentBounds)
        graphingWebView.setValue(false, forKey: "drawsBackground")
        scientificWebView = WKWebView(frame: contentBounds)
        scientificWebView.setValue(false, forKey: "drawsBackground")

        for view in [matrixWebView, graphingWebView, scientificWebView] {
            view!.autoresizingMask = [.width, .height]
            window.contentView?.addSubview(view!)
        }

        matrixWebView.load(URLRequest(url: URL(string: "https://www.desmos.com/matrix")!))
        graphingWebView.load(URLRequest(url: URL(string: "https://www.desmos.com/calculator")!))
        scientificWebView.load(URLRequest(url: URL(string: "https://www.desmos.com/scientific")!))

        // Show scientific by default
        matrixWebView.isHidden = true
        graphingWebView.isHidden = true
        scientificWebView.isHidden = false
        desmosWebView = scientificWebView
        
        // ---- ADD A TITLE BAR ACCESSORY WITH SETTINGS BUTTON ----
        let accessoryVC = NSTitlebarAccessoryViewController()
        // Instead of accessoryVC.layoutAttribute = .right
        accessoryVC.layoutAttribute = .left

        // Container with a single Settings (gear) button that shows a pop-down menu
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 30, height: 30))
        accessoryVC.view = containerView

        let settingsButton = NSButton(frame: NSRect(x: 0, y: 0, width: 25, height: 25))
        settingsButton.bezelStyle = .inline
        settingsButton.title = ""
        settingsButton.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: "Settings")
        settingsButton.action = #selector(showSettingsMenu(_:))
        settingsButton.target = self
        containerView.addSubview(settingsButton)

        // Then attach
        window.addTitlebarAccessoryViewController(accessoryVC)
        
        // Bold button setting
        let boldConfig = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .bold)
        let boldWhiteConfig = boldConfig.applying(.init(paletteColors: [.white]))
        // Create a second titlebar accessory for the right side
        let rightAccessoryVC = NSTitlebarAccessoryViewController()
        rightAccessoryVC.layoutAttribute = .right
        let rightContainer = NSView(frame: NSRect(x: 0, y: 0, width: 90, height: 30))
        rightAccessoryVC.view = rightContainer

        // Button to load Matrix
        matrixButton = NSButton(frame: NSRect(x: 0, y: 0, width: 25, height: 25))
        matrixButton.setButtonType(.toggle)
        matrixButton.bezelStyle = .inline
        matrixButton.title = ""
        matrixButton.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Matrix")
        matrixButton.alternateImage = NSImage(systemSymbolName: "tablecells",
                                              accessibilityDescription: "Matrix (selected)")?
            .withSymbolConfiguration(boldWhiteConfig)
        
        matrixButton.action = #selector(loadMatrix)
        matrixButton.target = self
        rightContainer.addSubview(matrixButton)

        // Button to load Graphing Calculator
        graphingButton = NSButton(frame: NSRect(x: 30, y: 0, width: 25, height: 25))
        graphingButton.setButtonType(.toggle)
        graphingButton.bezelStyle = .inline
        graphingButton.title = ""
        graphingButton.image = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "Graphing")
        graphingButton.alternateImage = NSImage(systemSymbolName: "chart.xyaxis.line",
                                                accessibilityDescription: "Graphing (selected)")?
            .withSymbolConfiguration(boldWhiteConfig)

        graphingButton.action = #selector(loadGraphing)
        graphingButton.target = self
        rightContainer.addSubview(graphingButton)
        
        // Button to load Scientific Calculator
        scientificButton = NSButton(frame: NSRect(x: 60, y: 0, width: 25, height: 25))
        scientificButton.setButtonType(.toggle)
        scientificButton.bezelStyle = .inline
        scientificButton.title = ""
        scientificButton.image = NSImage(systemSymbolName: "function", accessibilityDescription: "Scientific")
        scientificButton.alternateImage = NSImage(systemSymbolName: "function",
                                                  accessibilityDescription: "Scientific (selected)")?
            .withSymbolConfiguration(boldWhiteConfig)
        scientificButton.action = #selector(loadScientific)
        scientificButton.target = self
        rightContainer.addSubview(scientificButton)

        window.addTitlebarAccessoryViewController(rightAccessoryVC)
        // Highlight “Scientific” by default
        updateSelection(scientificButton)
        // ----------------------------------------------
       
        let wc = NSWindowController(window: window)
        desmosWindowController = wc
        wc.window?.orderOut(nil)
        toggleDesmosWindow()
    }
    
    /// Toggles the presence of the status bar icon without relying on a sender button.
    @objc private func toggleStatusIcon() {
        if isStatusItemVisible, let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
            isStatusItemVisible = false
        } else if !isStatusItemVisible {
            setupStatusItem()
            isStatusItemVisible = true
        }
    }

    @objc private func toggleStatusIconFromTitlebar(_ sender: NSButton) {
        toggleStatusIcon()
        // Update the button image only if such a button exists/was used
        sender.image = NSImage(systemSymbolName: isStatusItemVisible ? "eye" : "eye.slash",
                               accessibilityDescription: isStatusItemVisible ? "Hide Status Icon" : "Show Status Icon")
        sender.state = isStatusItemVisible ? .on : .off
    }

    /// Shows a pop-down settings menu anchored to the gear button.
    @objc private func showSettingsMenu(_ sender: NSButton) {
        let menu = NSMenu()

        // Show current hotkey
        let currentItem = NSMenuItem(title: "Hotkey: \(currentHotKeyDisplay)", action: nil, keyEquivalent: "")
        currentItem.isEnabled = false
        menu.addItem(currentItem)
        menu.addItem(NSMenuItem.separator())

        // 1) Change Hotkey…
        let hotkeyItem = NSMenuItem(title: "Set Hotkey", action: #selector(showHotkeyChangeDialog), keyEquivalent: "")
        hotkeyItem.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil)
        hotkeyItem.target = self
        menu.addItem(hotkeyItem)

        // 2) Toggle status bar icon item
        let toggleTitle = isStatusItemVisible ? "Hide Icon" : "Show Icon"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleStatusIconFromMenu(_:)), keyEquivalent: "")
        toggleItem.image = NSImage(systemSymbolName: isStatusItemVisible ? "eye.slash" : "eye", accessibilityDescription: nil)
        toggleItem.target = self
        menu.addItem(toggleItem)

        // 3) Quit item
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "")
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: nil)
        quitItem.target = self
        menu.addItem(quitItem)

        // Show as a pop-down under the gear button
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height - 2), in: sender)
    }

    /// Action invoked from the settings menu to toggle the status bar icon.
    @objc private func toggleStatusIconFromMenu(_ sender: Any?) {
        toggleStatusIcon()
    }

    @objc fileprivate func toggleDesmosWindow() {
#if DEBUG
        print("toggleDesmosWindow")
#endif
        guard let wc = desmosWindowController, let window = wc.window else { return }
        if window.isVisible {
            window.orderOut(nil)
        } else {
            wc.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Ensures the main window is visible, activated, then performs the provided action (like switching pages).
    private func showWindowAnd(then action: () -> Void) {
        action()
        if let wc = desmosWindowController {
            wc.showWindow(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    /// Open specific pages from the status menu (icons only)
    @objc private func openMatrixFromStatus() {
        showWindowAnd { loadMatrix() }
    }

    @objc private func openGraphingFromStatus() {
        showWindowAnd { loadGraphing() }
    }

    @objc private func openScientificFromStatus() {
        showWindowAnd { loadScientific() }
    }


    
    /// Switches the visible webview; reloads if already active, but only when window is visible
    private func switchTo(_ webView: WKWebView) {
        // If the requested webView is already active, only refresh when the window is visible
        if desmosWebView === webView {
            if let isVisible = desmosWindowController?.window?.isVisible, isVisible {
                webView.reload()
            }
            return
        }
        // Otherwise switch without forcing a refresh
        desmosWebView?.isHidden = true
        webView.isHidden = false
        desmosWebView = webView
    }

    /// Highlights the selected calculator button in bold white and dims the others
    private func updateSelection(_ selected: NSButton?) {
        let buttons = [matrixButton, graphingButton, scientificButton]
        for button in buttons {
            guard let button = button else { continue }
            button.state = (button == selected) ? .on : .off
        }
    }

    /// Returns a regular SF Symbol image for the status menu.
    private func statusImage(named: String) -> NSImage? {
        return NSImage(systemSymbolName: named, accessibilityDescription: nil)
    }

    /// Returns a "bright" (bold white) variant of the SF Symbol for the selected menu item.
    private func selectedStatusImage(named: String) -> NSImage? {
        let boldConfig = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .bold)
        let boldWhiteConfig = boldConfig.applying(.init(paletteColors: [.white]))
        return NSImage(systemSymbolName: named, accessibilityDescription: nil)?.withSymbolConfiguration(boldWhiteConfig)
    }

    /// Syncs the status-menu icons with the currently selected page (bright = selected).
    private func updateStatusMenuSelection() {
        // Scientific
        if let item = statusScientificItem {
            item.image = (desmosWebView === scientificWebView)
                ? selectedStatusImage(named: "function")
                : statusImage(named: "function")
        }
        // Graphing
        if let item = statusGraphingItem {
            item.image = (desmosWebView === graphingWebView)
                ? selectedStatusImage(named: "chart.xyaxis.line")
                : statusImage(named: "chart.xyaxis.line")
        }
        // Algebra (Matrix)
        if let item = statusAlgebraItem {
            item.image = (desmosWebView === matrixWebView)
                ? selectedStatusImage(named: "tablecells")
                : statusImage(named: "tablecells")
        }
    }

    // MARK: - Hotkey Registration
    func registerGlobalHotKey() {
        // Unregister any previous hotkey
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }

        // Prepare HotKeyID; keep ID == 0 to match our callback check
        let hotKeyID = EventHotKeyID(
            signature: OSType(UInt32(0x44440000)), // 'DD\0\0'
            id: UInt32(0)
        )

        // Register with current, mutable code/modifiers
        var newRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            currentHotKeyCode,
            currentHotKeyModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &newRef
        )

        if status != noErr {
            print("Failed to register hotkey, status \(status)")
            return
        }
        hotKeyRef = newRef

        // Install the handler only once
        var eventTypeSpec = EventTypeSpec(eventClass: kEventClassKeyboard, eventKind: kEventHotKeyPressed)
        if !hotKeyHandlerInstalled {
            InstallEventHandler(
                GetEventDispatcherTarget(),
                HotKeyHandlerCallback,
                1,
                &eventTypeSpec,
                UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                nil
            )
            hotKeyHandlerInstalled = true
        }
    }
    
    // Convert NSEvent.ModifierFlags to Carbon mask
    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option)  { carbon |= UInt32(optionKey) }
        if flags.contains(.shift)   { carbon |= UInt32(shiftKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        return carbon
    }

    // Make something like "⌘⌥D"
    private func displayString(modifiers: NSEvent.ModifierFlags, key: String) -> String {
        var s = ""
        if modifiers.contains(.command) { s += "⌘" }
        if modifiers.contains(.option)  { s += "⌥" }
        if modifiers.contains(.shift)   { s += "⇧" }
        if modifiers.contains(.control) { s += "⌃" }
        s += key.uppercased()
        return s
    }

    @objc private func showHotkeyChangeDialog() {
        beginHotkeyCapture()
    }

    // MARK: - Hotkey Capture
    /// Begin capturing a new hotkey via a sheet + local key monitor
    private func beginHotkeyCapture() {
        guard let window = desmosWindowController?.window else {
            print("No window available for hotkey capture.")
            return
        }

        let alert = NSAlert()
        alert.messageText = "Set Hotkey"
        alert.informativeText = "Press the new shortcut now (include at least one modifier: ⌘, ⌥, ⇧, or ⌃). Press Esc to cancel."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Cancel")

        // Local monitor captures the next keyDown
        hotkeyCaptureMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard let self = self else { return event }
            // Escape cancels
            if event.keyCode == kVK_Escape { // Esc
                self.endHotkeyCapture(alert: alert, window: window, cancelled: true)
                return nil
            }

            // Require at least one modifier
            let mods = event.modifierFlags.intersection([.command, .option, .shift, .control])
            if mods.isEmpty {
                NSSound.beep()
                return nil
            }

            // Determine key string
            let keyString = (event.charactersIgnoringModifiers ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if keyString.isEmpty {
                NSSound.beep()
                return nil
            }

            // Update and re-register
            self.currentHotKeyCode = UInt32(event.keyCode)
            self.currentHotKeyModifiers = self.carbonModifiers(from: mods)
            self.currentHotKeyDisplay = self.displayString(modifiers: mods, key: keyString)
            self.saveHotkeyToDefaults()
            self.registerGlobalHotKey()

            // Done
            self.endHotkeyCapture(alert: alert, window: window, cancelled: false)
            return nil
        })

        // Present as sheet so app stays key
        alert.beginSheetModal(for: window) { _ in
            // Cleanup handled in endHotkeyCapture
        }
    }

    private func saveHotkeyToDefaults() {
        let d = UserDefaults.standard
        d.set(Int(currentHotKeyCode), forKey: defaultsKeyHotKeyCode)
        d.set(Int(currentHotKeyModifiers), forKey: defaultsKeyHotKeyMods)
        d.set(currentHotKeyDisplay, forKey: defaultsKeyHotKeyDisplay)
    }

    private func loadHotkeyFromDefaults() {
        let d = UserDefaults.standard
        if d.object(forKey: defaultsKeyHotKeyCode) != nil,
           d.object(forKey: defaultsKeyHotKeyMods) != nil,
           let disp = d.string(forKey: defaultsKeyHotKeyDisplay) {
            currentHotKeyCode = UInt32(d.integer(forKey: defaultsKeyHotKeyCode))
            currentHotKeyModifiers = UInt32(d.integer(forKey: defaultsKeyHotKeyMods))
            currentHotKeyDisplay = disp
        }
    }

    private func endHotkeyCapture(alert: NSAlert, window: NSWindow, cancelled: Bool) {
        if let monitor = hotkeyCaptureMonitor {
            NSEvent.removeMonitor(monitor)
            hotkeyCaptureMonitor = nil
        }
        window.endSheet(alert.window)
        if cancelled {
            print("Hotkey capture cancelled.")
        } else {
            print("New hotkey set to: \(currentHotKeyDisplay)")
        }
    }

    /// Builds a custom status bar icon that draws a circle with two Desmos‑like wave lines.
    private func makePopupStatusIcon(pointSize: CGFloat = 18, lineWidth: CGFloat = 1.35) -> NSImage {
        let size = NSSize(width: pointSize, height: pointSize)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        // Use template black; system will tint to menu color (white in dark backgrounds)
        NSColor.black.setStroke()

        // Outer ring
        let ringWidth = max(1.6, lineWidth)
        let circleInset: CGFloat = ringWidth / 2.0 + 0.6
        let circleRect = NSRect(x: circleInset,
                                y: circleInset,
                                width: size.width - 2 * circleInset,
                                height: size.height - 2 * circleInset)
        let ring = NSBezierPath(ovalIn: circleRect)
        ring.lineWidth = ringWidth
        ring.lineCapStyle = .round
        ring.lineJoinStyle = .round
        ring.stroke()

        // Drawing area inside the ring
        let contentInset = circleInset + ringWidth * 0.8
        let content = NSInsetRect(NSRect(origin: .zero, size: size), contentInset, contentInset)
        let w = content.width
        let h = content.height
        let midX = content.midX
        let midY = content.midY

        // Wave stroke config
        let wave = NSBezierPath()
        wave.lineWidth = max(1.2, lineWidth) // slightly thicker than ring for presence
        wave.lineCapStyle = .round
        wave.lineJoinStyle = .round

        // First curve (the S-wave), vertically offset upward
        let verticalOffset: CGFloat = 0.1 * h
        let p0 = NSPoint(x: content.minX, y: midY - 0.28 * h + verticalOffset)
        let c1_wave = NSPoint(x: content.minX + 0.30 * w, y: midY + 0.55 * h + verticalOffset)
        let c2_wave = NSPoint(x: content.minX + 0.68 * w, y: midY - 0.65 * h + verticalOffset)
        let p1 = NSPoint(x: content.maxX, y: midY - 0.30 * h + verticalOffset)
        wave.move(to: p0)
        wave.curve(to: p1, controlPoint1: c1_wave, controlPoint2: c2_wave)
        wave.stroke()

        // --- MODIFICATION START ---
        // Instead of a second wave, draw a simple parabola.
        // 0 -> perfectly flat (straight line), 1 -> original depth, >1 -> tighter (deeper) curve
        let parabolaWidthFactor: CGFloat = 2.0
        // Positive values raise the parabola; negative lower it. Units are a fraction of content height.
        // Raises/lowers ONLY the parabola's bottom (vertex). Fraction of content height.
        // Positive = higher (shallower), negative = deeper.
        let parabolaVertexLift: CGFloat = 0.275

        let parabola = NSBezierPath()
        parabola.lineWidth = wave.lineWidth // Use same line width as the wave
        parabola.lineCapStyle = .round
        parabola.lineJoinStyle = .round

        // Define the points for the desired quadratic curve (parabola).
        let baselineY = midY + (0.1 + parabolaVertexLift) * h
        let startPoint = NSPoint(x: content.minX, y: baselineY)
        let endPoint   = NSPoint(x: content.maxX, y: baselineY)

        // Compute control point depth based on width factor: 0 = flat, 1 = current depth to content.minY
        let minYDepth = content.minY
        let controlY = baselineY
                     - (baselineY - minYDepth) * parabolaWidthFactor
                     + parabolaVertexLift * h
        let quadControlPoint = NSPoint(x: midX, y: controlY)

        // To draw a quadratic curve using NSBezierPath, we must convert its single
        // control point into two control points for the cubic `curve(to:...)` method.
        // The formula is C = P_start + (2/3)*(P_control - P_start)
        let c1_parabola = NSPoint(x: startPoint.x + (quadControlPoint.x - startPoint.x) * 2/3,
                                  y: startPoint.y + (quadControlPoint.y - startPoint.y) * 2/3)

        let c2_parabola = NSPoint(x: endPoint.x + (quadControlPoint.x - endPoint.x) * 2/3,
                                  y: endPoint.y + (quadControlPoint.y - endPoint.y) * 2/3)

        parabola.move(to: startPoint)
        parabola.curve(to: endPoint, controlPoint1: c1_parabola, controlPoint2: c2_parabola)
        parabola.stroke()
        // --- MODIFICATION END ---

        image.isTemplate = true
        return image
    }

    private func setupStatusItem() {
        // Create the status bar item (square length for icon)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Set the status bar icon (no text)
        if let button = statusItem?.button {
            button.image = makePopupStatusIcon()
            button.imagePosition = .imageOnly
            // Do NOT set action/target here; clicking should open the menu.
        }

        // Build an icon-only menu
        let menu = NSMenu()

        // 1) Function (Scientific)
        let scientificItem = NSMenuItem()
        scientificItem.title = "" // icon only
        scientificItem.action = #selector(openScientificFromStatus)
        scientificItem.target = self
        statusScientificItem = scientificItem
        menu.addItem(scientificItem)

        // 2) Graphing (Chart)
        let graphingItem = NSMenuItem()
        graphingItem.title = ""
        graphingItem.action = #selector(openGraphingFromStatus)
        graphingItem.target = self
        statusGraphingItem = graphingItem
        menu.addItem(graphingItem)

        // 3) Algebra (Matrix)
        let algebraItem = NSMenuItem()
        algebraItem.title = ""
        algebraItem.action = #selector(openMatrixFromStatus)
        algebraItem.target = self
        statusAlgebraItem = algebraItem
        menu.addItem(algebraItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Quit (at bottom)
        let quitItem = NSMenuItem()
        quitItem.title = ""
        quitItem.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit")
        quitItem.action = #selector(quitApp)
        quitItem.target = self
        menu.addItem(quitItem)

        // Set initial icon brightness according to current selected page
        updateStatusMenuSelection()

        // Attach the menu to the status item (clicking the icon opens this menu)
        statusItem?.menu = menu
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
