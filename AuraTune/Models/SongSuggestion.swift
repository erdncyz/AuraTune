import Foundation

/// Defines a song suggestion returned by Gemini AI
struct SongSuggestion: Codable, Equatable, Identifiable {
    var title: String
    var artist: String
    var message: String

    init(title: String, artist: String, message: String) {
        self.title = Self.sanitizeText(title)
        self.artist = Self.sanitizeText(artist)
        self.message = Self.sanitizeMessageText(message)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTitle = try container.decode(String.self, forKey: .title)
        let rawArtist = try container.decode(String.self, forKey: .artist)
        let rawMessage = try container.decode(String.self, forKey: .message)

        self.init(title: rawTitle, artist: rawArtist, message: rawMessage)
    }

    var stableKey: String {
        let normalizedTitle = title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let normalizedArtist = artist
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        return "\(normalizedTitle)|\(normalizedArtist)"
    }

    var id: String { stableKey }

    private static func sanitizeText(_ value: String) -> String {
        let unwantedScalars = CharacterSet(charactersIn: "\u{200B}\u{200C}\u{200D}\u{2060}\u{FEFF}\u{FFFD}")

        let filteredScalars = value.precomposedStringWithCanonicalMapping.unicodeScalars.filter { scalar in
            if unwantedScalars.contains(scalar) {
                return false
            }

            if CharacterSet.controlCharacters.contains(scalar),
               !CharacterSet.whitespacesAndNewlines.contains(scalar) {
                return false
            }

            return true
        }

        let cleaned = String(String.UnicodeScalarView(filteredScalars))
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: " ?\n ?", with: "\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned
    }

    private static func sanitizeMessageText(_ value: String) -> String {
        let base = sanitizeText(value)
        let tokens = base.split(whereSeparator: \ .isWhitespace)
        let cleanedTokens = tokens.filter { token in
            !containsUnexpectedScript(in: String(token))
        }

        let cleaned = cleanedTokens.joined(separator: " ")
            .replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? base : cleaned
    }

    private static func containsUnexpectedScript(in token: String) -> Bool {
        token.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x3040...0x30FF,
                 0x3400...0x4DBF,
                 0x4E00...0x9FFF,
                 0xAC00...0xD7AF,
                 0x0600...0x06FF,
                 0x0400...0x04FF,
                 0x0900...0x097F:
                return true
            default:
                return false
            }
        }
    }
}
