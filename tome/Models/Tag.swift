import Foundation
import SwiftData

/// Custom tag for categorizing books
@Model
final class Tag {
    var id: UUID = UUID()
    var name: String = ""
    var colorHex: String = "#007AFF"

    @Relationship(deleteRule: .nullify, inverse: \Book.tags)
    var books: [Book]?

    init(id: UUID = UUID(), name: String = "", colorHex: String = "#007AFF") {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}
