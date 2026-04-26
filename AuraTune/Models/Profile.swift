import Foundation

enum SongLanguagePreference: String, Codable, CaseIterable, Identifiable {
    case turkish = "tr"
    case english = "en"
    case random = "random"

    var id: String { rawValue }

    func title(isEnglish: Bool) -> String {
        switch self {
        case .turkish:
            return isEnglish ? "Turkish" : "Türkçe"
        case .english:
            return isEnglish ? "English" : "İngilizce"
        case .random:
            return isEnglish ? "Random" : "Rastgele"
        }
    }

    var promptInstruction: String {
        switch self {
        case .turkish:
            return "Recommend a Turkish-language song. Prioritize songs whose lyrics are primarily in Turkish."
        case .english:
            return "Recommend an English-language song. Prioritize songs whose lyrics are primarily in English."
        case .random:
            let pickTurkish = Bool.random()
            let language = pickTurkish ? "Turkish" : "English"
            return "Recommend a \(language)-language song for this recommendation. Prioritize songs whose lyrics are primarily in \(language). Do not mention that the choice was random."
        }
    }
}

/// Models the user's profile stored in Supabase `profiles` table
struct Profile: Codable, Identifiable, Equatable {
    static let maxGenreSelection = 10

    var id: UUID?
    var name: String
    var wakeUpTime: Date
    var genres: [String]
    var platform: String // e.g. "Spotify", "Apple Music", "YouTube Music"
    var songLanguage: SongLanguagePreference
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case wakeUpTime = "wake_up_time"
        case genres
        case platform
        case songLanguage = "song_language"
    }
    
    init(
        id: UUID? = nil,
        name: String = "",
        wakeUpTime: Date = Date(),
        genres: [String] = [],
        platform: String = "Spotify",
        songLanguage: SongLanguagePreference = .random
    ) {
        self.id = id
        self.name = name
        self.wakeUpTime = wakeUpTime
        self.genres = genres
        self.platform = platform
        self.songLanguage = songLanguage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        wakeUpTime = try container.decodeIfPresent(Date.self, forKey: .wakeUpTime) ?? Date()
        genres = try container.decodeIfPresent([String].self, forKey: .genres) ?? []
        platform = try container.decodeIfPresent(String.self, forKey: .platform) ?? "Spotify"
        songLanguage = try container.decodeIfPresent(SongLanguagePreference.self, forKey: .songLanguage) ?? .random
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(wakeUpTime, forKey: .wakeUpTime)
        try container.encode(genres, forKey: .genres)
        try container.encode(platform, forKey: .platform)
        try container.encode(songLanguage, forKey: .songLanguage)
    }
}
