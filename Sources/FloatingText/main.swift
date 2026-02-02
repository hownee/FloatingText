import Cocoa
import Carbon.HIToolbox

class OutlinedTextView: NSView {
    var text: String = "" {
        didSet { needsDisplay = true }
    }
    var font: NSFont = NSFont(name: "Impact", size: 42) ?? NSFont.systemFont(ofSize: 42, weight: .bold)
    var textColor: NSColor = .white
    var outlineColor: NSColor = .black
    var outlineWidth: CGFloat = 2.0

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        // Draw outline by drawing text with stroke
        let outlineAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: outlineColor,
            .strokeColor: outlineColor,
            .strokeWidth: outlineWidth,
            .paragraphStyle: paragraphStyle
        ]

        // Draw fill on top
        let fillAttributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraphStyle
        ]

        let attributedString = NSAttributedString(string: text, attributes: outlineAttributes)
        let size = attributedString.boundingRect(with: bounds.size, options: [.usesLineFragmentOrigin, .usesFontLeading])
        let y = (bounds.height - size.height) / 2

        let drawRect = NSRect(x: 0, y: y, width: bounds.width, height: size.height)

        // Draw outline first, then fill on top
        NSAttributedString(string: text, attributes: outlineAttributes).draw(in: drawRect)
        NSAttributedString(string: text, attributes: fillAttributes).draw(in: drawRect)
    }
}

class FloatingTextApp: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var textView: OutlinedTextView!
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

        // Create the outlined text view
        textView = OutlinedTextView(frame: window.contentView!.bounds)
        textView.textColor = .white
        textView.outlineColor = .black
        textView.outlineWidth = 3.0
        textView.font = NSFont(name: "Impact", size: 42) ?? NSFont.systemFont(ofSize: 42, weight: .bold)

        // Add shadow for extra depth
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowOffset = NSSize(width: 2, height: -2)
        shadow.shadowBlurRadius = 4
        textView.shadow = shadow

        textView.autoresizingMask = [.width, .height]
        window.contentView?.addSubview(textView)

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

            // Check if no significant modifiers are pressed (for remote support)
            // Allow shift as some remotes send it, but not cmd/ctrl/option
            let hasNoModifiers = !flags.contains(.maskCommand) &&
                                 !flags.contains(.maskControl) &&
                                 !flags.contains(.maskAlternate)

            // Ctrl+Option shortcuts (manual keyboard control)
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

            // Presentation remote support (no modifiers required)
            // These keys are commonly sent by presentation clickers:
            // - Page Down (121), Page Up (116)
            // - F5 often starts presentation, but we ignore it
            if hasNoModifiers {
                // Page Down (keycode 121) - Next
                if keyCode == 121 {
                    DispatchQueue.main.async {
                        app.nextText()
                    }
                    return nil
                }
                // Page Up (keycode 116) - Previous
                else if keyCode == 116 {
                    DispatchQueue.main.async {
                        app.previousText()
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
                // Ctrl+Option shortcuts
                if event.modifierFlags.contains([.control, .option]) {
                    if event.keyCode == 124 {
                        self?.nextText()
                        return nil
                    } else if event.keyCode == 123 {
                        self?.previousText()
                        return nil
                    }
                }
                // Remote/Page keys (no modifiers)
                let hasNoMods = !event.modifierFlags.contains(.command) &&
                                !event.modifierFlags.contains(.control) &&
                                !event.modifierFlags.contains(.option)
                if hasNoMods {
                    if event.keyCode == 121 { // Page Down
                        self?.nextText()
                        return nil
                    } else if event.keyCode == 116 { // Page Up
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
        textView.text = texts[currentIndex]

        // Animate the change
        textView.alphaValue = 0.3
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            textView.animator().alphaValue = 1.0
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