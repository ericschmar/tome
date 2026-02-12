import Foundation
import Observation
import SwiftUI
import SwiftData

/// Centralized navigation state management for sidebar navigation
@MainActor
@Observable
final class NavigationState {
    /// Currently selected sidebar destination
    var selectedDestination: NavigationDestination = .allBooks

    /// Currently selected book for detail view
    var selectedBook: Book?

    /// Currently selected search result from OpenLibrary
    var selectedSearchResult: BookDocument?

    /// Search text for filtering
    var searchText = ""

    /// Column visibility state
    var columnVisibility: NavigationSplitViewVisibility = .all

    /// Filter and sort state
    var selectedStatus: ReadingStatus?
    var selectedTag: Tag?
    var sortOption: LibraryViewModel.SortOption = .dateAdded

    /// Initialize with default state
    init() {}
}

/// Navigation destinations for the sidebar
enum NavigationDestination: Hashable {
    // Library sections
    case allBooks
    case currentlyReading
    case toRead
    case read

    // Add Book options
    case addBookSearch, addBookManual, addBookBulk

    // Dynamic tag
    case tag(Tag)

    // System
    case settings

    static func == (lhs: NavigationDestination, rhs: NavigationDestination) -> Bool {
        switch (lhs, rhs) {
        case (.allBooks, .allBooks),
             (.currentlyReading, .currentlyReading),
             (.toRead, .toRead),
             (.read, .read),
             (.addBookSearch, .addBookSearch),
             (.addBookManual, .addBookManual),
             (.addBookBulk, .addBookBulk),
             (.settings, .settings):
            return true
        case (.tag(let lhsTag), .tag(let rhsTag)):
            return lhsTag.id == rhsTag.id
        default:
            return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .allBooks:
            hasher.combine(0)
        case .currentlyReading:
            hasher.combine(1)
        case .toRead:
            hasher.combine(2)
        case .read:
            hasher.combine(3)
        case .addBookSearch:
            hasher.combine(4)
        case .addBookManual:
            hasher.combine(5)
        case .addBookBulk:
            hasher.combine(6)
        case .settings:
            hasher.combine(7)
        case .tag(let tag):
            hasher.combine(9)
            hasher.combine(tag.id)
        }
    }

    /// Display name for the destination
    var displayName: String {
        switch self {
        case .allBooks:
            return "All Books"
        case .currentlyReading:
            return "Currently Reading"
        case .toRead:
            return "To Read"
        case .read:
            return "Read"
        case .addBookSearch:
            return "Search"
        case .addBookManual:
            return "Manual"
        case .addBookBulk:
            return "Bulk Add"
        case .tag(let tag):
            return tag.name
        case .settings:
            return "Settings"
        }
    }

    /// SF Symbol icon for the destination
    var icon: String {
        switch self {
        case .allBooks:
            return "books.vertical"
        case .currentlyReading:
            return "book.fill"
        case .toRead:
            return "book"
        case .read:
            return "checkmark.circle.fill"
        case .addBookSearch:
            return "magnifyingglass"
        case .addBookManual:
            return "pencil"
        case .addBookBulk:
            return "rectangle.stack.badge.plus"
        case .tag:
            return "tag.fill"
        case .settings:
            return "gear"
        }
    }

    /// Section for grouping in sidebar
    var section: NavigationSection {
        switch self {
        case .allBooks, .currentlyReading, .toRead, .read:
            return .library
        case .addBookSearch, .addBookManual, .addBookBulk:
            return .addBook
        case .tag:
            return .tags
        case .settings:
            return .system
        }
    }
}

/// Sections for organizing the sidebar
enum NavigationSection: String, CaseIterable {
    case library = "Library"
    case addBook = "Add Book"
    case tags = "Tags"
    case system = "System"
}
