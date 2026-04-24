import Foundation

/// Defines a song suggestion returned by Gemini AI
struct SongSuggestion: Codable, Equatable {
    var title: String
    var artist: String
    var message: String

    var stableKey: String {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedArtist = artist
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(normalizedTitle)|\(normalizedArtist)"
    }
}
