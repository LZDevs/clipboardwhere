import Foundation

enum Constants {
    static let maxItems = 50
    static let pollInterval: TimeInterval = 0.5
    static let appName = "ClipboardWhere"
    static let version = "0.6.0"
    static let repoURL = "https://github.com/LZDevs/clipboardwhere"

    static let supportDir: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("ClipboardWhere")
    }()

    static let historyFile: URL = {
        supportDir.appendingPathComponent("history.json")
    }()

    static let imagesDir: URL = {
        supportDir.appendingPathComponent("images")
    }()
}

extension Notification.Name {
    static let clipboardUpdated = Notification.Name("clipboardUpdated")
    static let togglePanel = Notification.Name("togglePanel")
    static let pasteItem = Notification.Name("pasteItem")
}
