import Foundation

struct RecentFile: Codable, Identifiable {
    let id: UUID
    let url: URL
    var isCompleted: Bool
    var lastOpenedAt: Date

    init(url: URL, isCompleted: Bool = false, lastOpenedAt: Date = Date()) {
        self.id = UUID()
        self.url = url
        self.isCompleted = isCompleted
        self.lastOpenedAt = lastOpenedAt
    }
}