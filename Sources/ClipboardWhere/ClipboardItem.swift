import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    var isPinned: Bool
    let imageFileName: String?

    var isImage: Bool { imageFileName != nil }

    init(text: String, isPinned: Bool = false) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.isPinned = isPinned
        self.imageFileName = nil
    }

    init(imageFileName: String, isPinned: Bool = false) {
        self.id = UUID()
        self.text = ""
        self.timestamp = Date()
        self.isPinned = isPinned
        self.imageFileName = imageFileName
    }

    var preview: String {
        if isImage { return "Image" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 {
            return trimmed
        }
        return String(trimmed.prefix(80)) + "..."
    }

    var imageURL: URL? {
        guard let name = imageFileName else { return nil }
        return Constants.imagesDir.appendingPathComponent(name)
    }
}
