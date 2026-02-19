import AppKit
import SwiftUI
import Combine

/// Shared state between PanelController (key events) and ClipboardListView (display)
final class PanelState: ObservableObject {
    @Published var selectedIndex = 0
    @Published var pasteRequested = false
    var filteredCount = 0

    func reset() {
        selectedIndex = 0
        pasteRequested = false
    }
}

final class PanelController {
    private var panel: FloatingPanel?
    private let store: ClipboardStore
    private let panelState = PanelState()
    private var keyMonitor: Any?
    private var clickMonitor: Any?
    private var previousApp: NSRunningApplication?

    init(store: ClipboardStore) {
        self.store = store
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        panelState.reset()

        // Remember which app was active BEFORE we show the panel
        previousApp = NSWorkspace.shared.frontmostApplication

        createPanel()
        positionPanel()
        installMonitors()
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        removeMonitors()
        panel?.orderOut(nil)
    }

    /// Hide the panel, reactivate the previous app, then paste
    func hideAndPaste(_ text: String) {
        removeMonitors()
        panel?.orderOut(nil)

        // Reactivate the app that was focused before we opened
        if let app = previousApp {
            app.activate(options: .activateIgnoringOtherApps)
        }

        // Post paste notification after the previous app has time to regain focus
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            NotificationCenter.default.post(name: .pasteItem, object: text)
        }
    }

    private func createPanel() {
        panel?.orderOut(nil)

        let frame = NSRect(x: 0, y: 0, width: 360, height: 420)
        panel = FloatingPanel(contentRect: frame)

        let controller = self
        let listView = ClipboardListView(store: store, panelState: panelState,
            onDismiss: { [weak controller] in controller?.hide() },
            onPaste: { [weak controller] text in controller?.hideAndPaste(text) }
        )
        let hostingView = NSHostingView(rootView: listView)
        panel?.contentView = hostingView
    }

    private func positionPanel() {
        guard let panel = panel, let screen = NSScreen.main else { return }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        var x = mouseLocation.x - panelSize.width / 2
        var y = mouseLocation.y - panelSize.height

        x = max(screenFrame.minX, min(x, screenFrame.maxX - panelSize.width))
        y = max(screenFrame.minY, min(y, screenFrame.maxY - panelSize.height))

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Event Monitors

    private func installMonitors() {
        removeMonitors()

        // Keyboard monitor (local — events within our app)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self, self.isVisible else { return event }
            return self.handleKeyEvent(event)
        }

        // Click-outside monitor (global — events in other apps)
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self = self, self.isVisible else { return }
            self.hide()
        }
    }

    private func removeMonitors() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        switch event.keyCode {
        case 126: // Up arrow
            moveSelection(-1)
            return nil
        case 125: // Down arrow
            moveSelection(1)
            return nil
        case 36: // Return
            panelState.pasteRequested = true
            return nil
        case 53: // Escape
            hide()
            return nil
        default:
            return event
        }
    }

    private func moveSelection(_ delta: Int) {
        let count = panelState.filteredCount
        guard count > 0 else { return }
        let newIndex = max(0, min(count - 1, panelState.selectedIndex + delta))
        panelState.selectedIndex = newIndex
    }
}
