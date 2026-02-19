import AppKit

final class ClipboardMonitor {
    private let store: ClipboardStore
    private var timer: Timer?
    private var lastChangeCount: Int

    /// Flag to suppress re-capturing our own paste writes
    var suppressNextCapture = false

    init(store: ClipboardStore) {
        self.store = store
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: Constants.pollInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        if suppressNextCapture {
            suppressNextCapture = false
            return
        }

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        store.add(text)
    }
}
