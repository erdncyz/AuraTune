import Foundation

/// Models the user's profile stored in Supabase `profiles` table
struct Profile: Codable, Identifiable, Equatable {
    var id: UUID?
    var name: String
    var wakeUpTime: Date
    var genres: [String]
    var platform: String // e.g. "Spotify", "Apple Music", "YouTube Music"
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case wakeUpTime = "wake_up_time"
        case genres
        case platform
    }
    
    init(id: UUID? = nil, name: String = "", wakeUpTime: Date = Date(), genres: [String] = [], platform: String = "Spotify") {
        self.id = id
        self.name = name
        self.wakeUpTime = wakeUpTime
        self.genres = genres
        self.platform = platform
    }
}
