////
//  AppDelegate.swift
//  DesmosPopUp
//
//  Created by Oori Schubert on 1/18/25.
//

import Cocoa
import Carbon.HIToolbox
import WebKit

// (1) Manually define missing Carbon constants (if not in bridging header)
public let kEventParamNameHotKeyID: UInt32 = 0x686B6964  // 'hkid'
public let typeEventHotKeyID: UInt32      = 0x686B6964   // 'hkid'
public let kEventClassKeyboard: UInt32    = 0x6B657962   // 'keyb'
public let kEventHotKeyPressed: UInt32   = 6
public let kVK_ANSI_D: Int32             = 2

// (2) Define the callback as a top-level C function
//     In 64-bit, we do not need NewEventHandlerUPP.

func HotKeyHandlerCallback(
    callRef: EventHandlerCallRef?,
    eventRef: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    print("HotKeyHandlerCallback triggered!")
    // Extract the hotkey ID
    let hkID = EventHotKeyID()
//    let err = GetEventParameter(
//        eventRef,
//        EventParamName(kEventParamNameHotKeyID),
//        EventParamType(typeEventHotKeyID),
//        nil,
//        MemoryLayout.size(ofValue: hkID),
//        nil,
//        &hkID
//    )
    print("ID",hkID.id)
    let eventClass = GetEventClass(eventRef)
    let eventKind = GetEventKind(eventRef)
    print("Event class:", eventClass, "Event kind:", eventKind)
    //guard err == noErr else { return noErr }
    
    // If it matches our ID, toggle the Desmos window
    if hkID.id == 0, let userData = userData {  //changed from 1
        let mySelf = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        mySelf.toggleDesmosWindow()
    }
    return noErr
}

@objc class AppDelegate: NSObject, NSApplicationDelegate {
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

    @objc func loadMatrix() {
        switchTo(matrixWebView)
        updateSelection(matrixButton)
    }

    @objc func loadGraphing() {
        switchTo(graphingWebView)
        updateSelection(graphingButton)
    }
    
    @objc func loadScientific() {
        switchTo(scientificWebView)
        updateSelection(scientificButton)
    }
    

    var desmosWindowController: NSWindowController?
    var statusItem: NSStatusItem?
    var isStatusItemVisible = true

        func applicationDidFinishLaunching(_ aNotification: Notification) {
            setupDesmosWindow()
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
        window.isReleasedWhenClosed = false
        window.level = .floating

        // Preload the three calculator webviews
        let contentBounds = window.contentView!.bounds

        matrixWebView = WKWebView(frame: contentBounds)
        graphingWebView = WKWebView(frame: contentBounds)
        scientificWebView = WKWebView(frame: contentBounds)

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
        
        // ---- ADD A TITLE BAR ACCESSORY WITH TWO ICON BUTTONS ----
            let accessoryVC = NSTitlebarAccessoryViewController()
        // Instead of accessoryVC.layoutAttribute = .right
        accessoryVC.layoutAttribute = .left

        // For example, a 90-wide container, placing your 3 icons from left to right:
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 60, height: 30))
        accessoryVC.view = containerView

        // 1) Quit button (left-most, near traffic lights)
        let quitButton = NSButton(frame: NSRect(x: 0, y: 0, width: 25, height: 25))
        quitButton.bezelStyle = .inline
        quitButton.title = ""
        quitButton.image = NSImage(systemSymbolName: "xmark.circle", accessibilityDescription: "Quit Desmos")
        quitButton.action = #selector(quitApp)
        quitButton.target = self
        containerView.addSubview(quitButton)


        // 3) Toggle icon (right-most)
        let iconToggleButton = NSButton(frame: NSRect(x: 30, y: 0, width: 25, height: 25))
        iconToggleButton.bezelStyle = .inline
        iconToggleButton.setButtonType(.toggle)
        iconToggleButton.title = ""
        iconToggleButton.image = NSImage(systemSymbolName: "eye", accessibilityDescription: "Toggle Status Icon")
        iconToggleButton.state = isStatusItemVisible ? .on : .off
        iconToggleButton.action = #selector(toggleStatusIconFromTitlebar(_:))
        iconToggleButton.target = self
        containerView.addSubview(iconToggleButton)
        
        // Bold button setting
        let boldConfig = NSImage.SymbolConfiguration(pointSize: NSFont.systemFontSize, weight: .bold)
        let boldWhiteConfig = boldConfig.applying(.init(paletteColors: [.white]))

        // Then attach
        window.addTitlebarAccessoryViewController(accessoryVC)
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
        print("Window setup!")
        toggleDesmosWindow()
    }
    
    @objc func toggleStatusIconFromTitlebar(_ sender: NSButton) {
        if sender.state == .on {
            // Show the status icon, set normal “function” image
            if !isStatusItemVisible {
                setupStatusItem()
                isStatusItemVisible = true
            }
            // Switch the button’s icon to “function”
            sender.image = NSImage(systemSymbolName: "eye",
                                   accessibilityDescription:  "Hide Status Icon")
        } else {
            // Hide the status icon
            if isStatusItemVisible, let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
                isStatusItemVisible = false
            }
            // Switch the button’s icon to an “X” symbol
            sender.image = NSImage(systemSymbolName: "eye.slash",
                                   accessibilityDescription: "Show Status Icon")
        }
    }

        @objc func toggleDesmosWindow() {
            print("toggleDesmosWindow called!")
            guard let wc = desmosWindowController, let window = wc.window else { return }
            if window.isVisible {
                window.orderOut(nil)
            } else {
                wc.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }


    
    /// Switches the visible webview; reloads if already active
    func switchTo(_ webView: WKWebView) {
        if desmosWebView === webView {
            webView.reload()
            return
        }
        desmosWebView?.isHidden = true
        webView.isHidden = false
        desmosWebView = webView
    }

    /// Highlights the selected calculator button in bold white and dims the others
    func updateSelection(_ selected: NSButton?) {
        let buttons = [matrixButton, graphingButton, scientificButton]
        for button in buttons {
            guard let button = button else { continue }
            button.state = (button == selected) ? .on : .off
        }
    }


    func registerGlobalHotKey() {
        // Example: Command + D
//        let keyCode = UInt32(kVK_ANSI_D)
//        let modifiers = UInt32(cmdKey)
        let keyCode = UInt32(kVK_ANSI_D) // G key
        let modifiers = UInt32(optionKey) // Command+Option+G
        
        // Create an EventHotKeyID
        let hotKeyID = EventHotKeyID(
            signature: OSType(UInt32(0x44440000)), // 'DD\0\0'
            id: UInt32(1)
        )

        // Register the hotkey
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )
        
        if status != noErr {
            print("Failed to register hotkey, status \(status)")
            return
        }
        
        // Create an EventTypeSpec describing "Hot Key Pressed"
        var eventTypeSpec = EventTypeSpec(
            eventClass: kEventClassKeyboard,
            eventKind: kEventHotKeyPressed
        )

        // (3) Pass our function pointer directly:
        InstallEventHandler(
            GetEventDispatcherTarget(),
            HotKeyHandlerCallback,  // no NewEventHandlerUPP needed
            1,
            &eventTypeSpec,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            nil
        )
    }
    
    // The rest of your code:
    // statusItem, setupDesmosWindow, toggleDesmosWindow, etc.
    
    func setupStatusItem() {
            // Create the menu bar icon
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            if let button = statusItem?.button {
                button.image = NSImage(systemSymbolName: "d.circle", accessibilityDescription: nil)
                button.action = #selector(toggleDesmosWindow)
                button.target = self
            }
        }
    
    @objc func showHotkeyChangeDialog() {
        // Placeholder: If you want to let the user pick another hotkey,
        // you’d show a custom UI or an NSAlert.
        // Then you'd re-register your hotkey with new code or modifiers.
        print("User wants to change hotkey… (not implemented yet)")
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
}
