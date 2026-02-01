import Cocoa
import Carbon.HIToolbox

class FloatingTextApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var textField: NSTextField!
    var texts: [String] = []
    var currentIndex: Int = 0
    var eventTap: CFMachPort?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadTexts()
        setupWindow()
        setupGlobalShortcuts()
        updateText()

        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
    }

    func loadTexts() {
        // Look for demo_texts.txt in several locations
        let possiblePaths = [
            // Same directory as executable
            Bundle.main.bundlePath + "/../demo_texts.txt",
            // Current working directory
            FileManager.default.currentDirectoryPath + "/demo_texts.txt",
            // Home directory
            NSHomeDirectory() + "/demo_texts.txt",
            // Project root (for development)
            Bundle.main.bundlePath + "/../../../../demo_texts.txt"
        ]

        var content: String? = nil
        for path in possiblePaths {
            let url = URL(fileURLWithPath: path).standardized
            if let fileContent = try? String(contentsOf: url, encoding: .utf8) {
                content = fileContent
                print("Loaded texts from: \(url.path)")
                break
            }
        }

        if let content = content {
            texts = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        }

        if texts.isEmpty {
            texts = ["No texts loaded - create demo_texts.txt"]
        }
    }

    func setupWindow() {
        // Create a borderless, transparent window
        let screenFrame = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let windowRect = NSRect(x: screenFrame.midX - 400, y: screenFrame.height - 150, width: 800, height: 100)

        window = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Make it float above everything
        window.level = .screenSaver
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = false
        window.ignoresMouseEvents = true  // Click-through
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]

        // Create the text field
        textField = NSTextField(frame: window.contentView!.bounds)
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.textColor = .white
        textField.font = NSFont.systemFont(ofSize: 42, weight: .bold)
        textField.alignment = .center
        textField.lineBreakMode = .byWordWrapping
        textField.maximumNumberOfLines = 3

        // Add shadow to text for readability
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowOffset = NSSize(width: 2, height: -2)
        shadow.shadowBlurRadius = 4
        textField.shadow = shadow

        textField.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(textField)

        window.orderFrontRegardless()
    }

    func setupGlobalShortcuts() {
        // Request accessibility permissions
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        if !trusted {
            print("⚠️  Please grant Accessibility permissions in System Preferences")
            print("   System Preferences → Privacy & Security → Accessibility")
        }

        // Create event tap for global keyboard monitoring
        let eventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<FloatingTextApp>.fromOpaque(refcon).takeUnretainedValue()

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Check for Ctrl+Option modifier
            let hasCtrlOption = flags.contains(.maskControl) && flags.contains(.maskAlternate)

            if hasCtrlOption {
                // Right arrow (keycode 124) - Next
                if keyCode == 124 {
                    DispatchQueue.main.async {
                        app.nextText()
                    }
                    return nil  // Consume the event
                }
                // Left arrow (keycode 123) - Previous
                else if keyCode == 123 {
                    DispatchQueue.main.async {
                        app.previousText()
                    }
                    return nil  // Consume the event
                }
                // Q (keycode 12) - Quit
                else if keyCode == 12 {
                    DispatchQueue.main.async {
                        NSApp.terminate(nil)
                    }
                    return nil
                }
            }

            return Unmanaged.passUnretained(event)
        }

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: refcon
        ) else {
            print("Failed to create event tap - accessibility permissions required")

            // Fallback: use local monitor (works when app is frontmost)
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.modifierFlags.contains([.control, .option]) {
                    if event.keyCode == 124 {
                        self?.nextText()
                        return nil
                    } else if event.keyCode == 123 {
                        self?.previousText()
                        return nil
                    }
                }
                return event
            }
            return
        }

        self.eventTap = tap

        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func nextText() {
        currentIndex = (currentIndex + 1) % texts.count
        updateText()
    }

    func previousText() {
        currentIndex = (currentIndex - 1 + texts.count) % texts.count
        updateText()
    }

    func updateText() {
        textField.stringValue = texts[currentIndex]

        // Animate the change
        textField.alphaValue = 0.3
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            textField.animator().alphaValue = 1.0
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }
}

// Main entry point
let app = NSApplication.shared
let delegate = FloatingTextApp()
app.delegate = delegate
app.run()
