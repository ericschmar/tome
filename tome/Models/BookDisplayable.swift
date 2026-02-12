import Foundation

/// Protocol for types that can be displayed as book details
protocol BookDisplayable {
    var title: String { get }
    var authors: [String] { get }
    var publisher: String? { get }
    var publishers: [String] { get }
    var firstPublishYear: Int? { get }
    var pageCount: Int? { get }
    var language: String? { get }
    var languages: [String] { get }
    var subjects: [String] { get }
    var bookDescription: String? { get }
    var isbn: String? { get }
}
