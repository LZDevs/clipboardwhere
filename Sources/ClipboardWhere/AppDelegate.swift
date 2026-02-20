import AppKit
import Carbon.HIToolbox

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let store = ClipboardStore()
    private var monitor: ClipboardMonitor!
    private var panelController: PanelController!
    private var hotKeyRef: EventHotKeyRef?
    private var pasteObserver: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusItem()
        setupClipboardMonitor()
        setupPanelController()
        registerGlobalHotKey()
        observePasteRequests()
        promptAccessibilityIfNeeded()
    }

    func applicationWillTerminate(_ notification: Notification) {
        unregisterGlobalHotKey()
        monitor.stop()
    }

    // MARK: - Accessibility

    private func promptAccessibilityIfNeeded() {
        // Small delay so the app is fully launched before prompting
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !PasteSimulator.isTrusted {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permission Required"
                alert.informativeText = "ClipboardWhere needs Accessibility access to paste items into other apps.\n\nClick \"Open Settings\" and add ClipboardWhere to the list."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Later")

                if alert.runModal() == .alertFirstButtonReturn {
                    PasteSimulator.openAccessibilitySettings()
                }
            }
        }
    }

    // MARK: - Main Menu (Cmd+Q support)

    private func setupMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(title: "Quit ClipboardWhere", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        NSApp.mainMenu = mainMenu
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "ClipboardWhere")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show History (⌘⌥V)", action: #selector(togglePanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Check Accessibility...", action: #selector(checkAccessibility), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Quit ClipboardWhere", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func clearHistory() {
        store.clearAll()
    }

    @objc private func checkAccessibility() {
        if PasteSimulator.isTrusted {
            let alert = NSAlert()
            alert.messageText = "Accessibility Access Granted"
            alert.informativeText = "ClipboardWhere has the permissions it needs. Paste should work."
            alert.alertStyle = .informational
            alert.runModal()
        } else {
            PasteSimulator.checkAccessibility()
            PasteSimulator.openAccessibilitySettings()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Clipboard Monitoring

    private func setupClipboardMonitor() {
        monitor = ClipboardMonitor(store: store)
        monitor.start()
    }

    // MARK: - Panel

    private func setupPanelController() {
        panelController = PanelController(store: store)
    }

    // MARK: - Paste

    private func observePasteRequests() {
        pasteObserver = NotificationCenter.default.addObserver(
            forName: .pasteItem,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let item = notification.object as? ClipboardItem else { return }
            PasteSimulator.paste(item, monitor: self.monitor)
        }
    }

    // MARK: - Global Hot Key (Carbon)

    private let hotKeyID = EventHotKeyID(signature: OSType(0x434C5057), id: 1) // "CLPW"

    private func registerGlobalHotKey() {
        var ref: EventHotKeyRef?

        let modifiers: UInt32 = UInt32(cmdKey | optionKey)
        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )

        guard status == noErr else {
            print("Failed to register hotkey: \(status)")
            return
        }
        hotKeyRef = ref

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, _) -> OSStatus in
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )

                if hkID.id == 1 {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .togglePanel, object: nil)
                    }
                }
                return noErr
            },
            1,
            &eventType,
            nil,
            nil
        )

        NotificationCenter.default.addObserver(
            forName: .togglePanel,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.panelController.toggle()
        }
    }

    private func unregisterGlobalHotKey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
