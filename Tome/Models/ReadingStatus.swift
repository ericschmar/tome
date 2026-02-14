import Foundation

/// Reading status for tracking book progress
enum ReadingStatus: String, Codable, CaseIterable {
    case toRead = "To Read"
    case reading = "Reading"
    case read = "Read"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .toRead: return "book.closed"
        case .reading: return "book"
        case .read: return "book.fill"
        }
    }
}
