import Foundation

struct ClipboardItem: Codable, Identifiable, Equatable {
    let id: UUID
    let text: String
    let timestamp: Date
    var isPinned: Bool

    init(text: String, isPinned: Bool = false) {
        self.id = UUID()
        self.text = text
        self.timestamp = Date()
        self.isPinned = isPinned
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 80 {
            return trimmed
        }
        return String(trimmed.prefix(80)) + "..."
    }
}
