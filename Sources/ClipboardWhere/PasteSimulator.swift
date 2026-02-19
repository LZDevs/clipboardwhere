import AppKit
import Carbon.HIToolbox
import ApplicationServices

enum PasteSimulator {
    static func paste(_ text: String, monitor: ClipboardMonitor) {
        guard isTrusted else {
            monitor.suppressNextCapture = true
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Needed"
                alert.informativeText = "ClipboardWhere can't paste automatically without Accessibility access.\n\nThe text has been copied to your clipboard — you can paste manually with ⌘V.\n\nClick \"Open Settings\" to grant permission, then restart the app."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "OK")
                if alert.runModal() == .alertFirstButtonReturn {
                    openAccessibilitySettings()
                }
            }
            return
        }

        monitor.suppressNextCapture = true

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            simulateCmdV()
        }
    }

    // MARK: - Accessibility

    @discardableResult
    static func checkAccessibility() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Paste

    private static func simulateCmdV() {
        let source = CGEventSource(stateID: .hidSystemState)

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            return
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
