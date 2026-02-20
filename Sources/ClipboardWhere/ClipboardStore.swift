import Foundation

final class ClipboardStore: ObservableObject {
    @Published var items: [ClipboardItem] = []

    init() {
        load()
    }

    func add(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Deduplication: if same text exists, move it to top (preserve pin state)
        let existingPinState = items.first(where: { $0.text == text })?.isPinned ?? false
        items.removeAll { $0.text == text }

        let item = ClipboardItem(text: text, isPinned: existingPinState)
        items.insert(item, at: 0)

        enforceMaxLimit()
        save()
        NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
    }

    func addImage(_ imageData: Data) {
        let fileName = UUID().uuidString + ".png"
        let fileURL = Constants.imagesDir.appendingPathComponent(fileName)

        do {
            let dir = Constants.imagesDir
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            try imageData.write(to: fileURL, options: .atomic)
        } catch {
            print("ClipboardStore: failed to save image — \(error)")
            return
        }

        let item = ClipboardItem(imageFileName: fileName)
        items.insert(item, at: 0)

        enforceMaxLimit()
        save()
        NotificationCenter.default.post(name: .clipboardUpdated, object: nil)
    }

    func delete(_ item: ClipboardItem) {
        items.removeAll { $0.id == item.id }
        if let url = item.imageURL {
            try? FileManager.default.removeItem(at: url)
        }
        save()
    }

    func togglePin(_ item: ClipboardItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isPinned.toggle()
        save()
    }

    func clearAll() {
        items.removeAll()
        // Delete all image files
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: Constants.imagesDir, includingPropertiesForKeys: nil) {
            for file in files {
                try? fm.removeItem(at: file)
            }
        }
        save()
    }

    var pinnedItems: [ClipboardItem] {
        items.filter { $0.isPinned }
    }

    // MARK: - Private

    private func enforceMaxLimit() {
        if items.count > Constants.maxItems {
            var kept: [ClipboardItem] = []
            for item in items {
                if item.isPinned || kept.count < Constants.maxItems {
                    kept.append(item)
                }
            }
            // Delete image files for removed items
            let removedItems = items.filter { item in !kept.contains(where: { $0.id == item.id }) }
            for removed in removedItems {
                if let url = removed.imageURL {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            items = kept
        }
    }

    // MARK: - Persistence

    private func save() {
        do {
            let dir = Constants.supportDir
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let data = try JSONEncoder().encode(items)
            try data.write(to: Constants.historyFile, options: .atomic)
        } catch {
            print("ClipboardStore: failed to save — \(error)")
        }
    }

    private func load() {
        do {
            let data = try Data(contentsOf: Constants.historyFile)
            items = try JSONDecoder().decode([ClipboardItem].self, from: data)
        } catch {
            items = []
        }
    }
}
