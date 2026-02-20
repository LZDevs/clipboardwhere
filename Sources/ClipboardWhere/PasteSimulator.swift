import AppKit
import Carbon.HIToolbox
import ApplicationServices

enum PasteSimulator {
    static func paste(_ item: ClipboardItem, monitor: ClipboardMonitor) {
        monitor.suppressNextCapture = true

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.isImage {
            guard let url = item.imageURL,
                  let imageData = try? Data(contentsOf: url),
                  let image = NSImage(data: imageData) else {
                return
            }
            pasteboard.writeObjects([image])
        } else {
            pasteboard.setString(item.text, forType: .string)
        }

        guard isTrusted else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Needed"
                alert.informativeText = item.isImage
                    ? "ClipboardWhere can't paste automatically without Accessibility access.\n\nThe image has been copied to your clipboard — you can paste manually with \u{2318}V.\n\nClick \"Open Settings\" to grant permission, then restart the app."
                    : "ClipboardWhere can't paste automatically without Accessibility access.\n\nThe text has been copied to your clipboard — you can paste manually with \u{2318}V.\n\nClick \"Open Settings\" to grant permission, then restart the app."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "OK")
                if alert.runModal() == .alertFirstButtonReturn {
                    openAccessibilitySettings()
                }
            }
            return
        }

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
