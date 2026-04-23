import Foundation

/// Defines a song suggestion returned by Gemini AI
struct SongSuggestion: Codable, Equatable {
    var title: String
    var artist: String
    var message: String
}
