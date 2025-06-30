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

    @objc func loadMatrix() {
        guard let webView = desmosWebView,
              let url = URL(string: "https://www.desmos.com/matrix")
        else { return }
        webView.load(URLRequest(url: url))
    }

    @objc func loadGraphing() {
        guard let webView = desmosWebView,
              let url = URL(string: "https://www.desmos.com/calculator")
        else { return }
        webView.load(URLRequest(url: url))
    }
    
    @objc func loadScientific() {
        guard let webView = desmosWebView,
              let url = URL(string: "https://www.desmos.com/scientific")
        else { return }
        webView.load(URLRequest(url: url))
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

        // Create a WKWebView
        desmosWebView = WKWebView(frame: window.contentView!.bounds)
        guard let webView = desmosWebView else { return }
        webView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(webView)
        

        // Load Desmos
        loadScientific()
        
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

        // Then attach
        window.addTitlebarAccessoryViewController(accessoryVC)
        // Create a second titlebar accessory for the right side
        let rightAccessoryVC = NSTitlebarAccessoryViewController()
        rightAccessoryVC.layoutAttribute = .right
        let rightContainer = NSView(frame: NSRect(x: 0, y: 0, width: 90, height: 30))
        rightAccessoryVC.view = rightContainer

        // Button to load Matrix
        let matrixButton = NSButton(frame: NSRect(x: 0, y: 0, width: 25, height: 25))
        matrixButton.bezelStyle = .inline
        matrixButton.title = ""
        matrixButton.image = NSImage(systemSymbolName: "tablecells", accessibilityDescription: "Matrix")
        matrixButton.action = #selector(loadMatrix)
        matrixButton.target = self
        rightContainer.addSubview(matrixButton)

        // Button to load Graphing Calculator
        let graphingButton = NSButton(frame: NSRect(x: 30, y: 0, width: 25, height: 25))
        graphingButton.bezelStyle = .inline
        graphingButton.title = ""
        graphingButton.image = NSImage(systemSymbolName: "chart.xyaxis.line", accessibilityDescription: "Graphing")
        graphingButton.action = #selector(loadGraphing)
        graphingButton.target = self
        rightContainer.addSubview(graphingButton)
        
        // Button to load Scientific Calculator
        let scientificButton = NSButton(frame: NSRect(x: 60, y: 0, width: 25, height: 25))
        scientificButton.bezelStyle = .inline
        scientificButton.title = ""
        scientificButton.image = NSImage(systemSymbolName: "function", accessibilityDescription: "Scientific")
        scientificButton.action = #selector(loadScientific)
        scientificButton.target = self
        rightContainer.addSubview(scientificButton)

        window.addTitlebarAccessoryViewController(rightAccessoryVC)
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
