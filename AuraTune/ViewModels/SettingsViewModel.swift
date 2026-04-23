import Foundation
import SwiftUI
import Combine

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var wakeUpTime: Date = Date()
    @Published var selectedGenres: Set<String> = []
    @Published var userName: String = ""
    @Published var selectedPlatform: String = "Spotify"
    @Published var isSaving = false
    
    let availableGenres = [
        "Pop", "Rock", "Lo-Fi", "Jazz", "Classical", "Hip-Hop", "Electronic", "Indie",
        "R&B", "Country", "Metal", "K-Pop", "Reggae", "Blues", "Soul", "Funk",
        "Punk", "Folk", "Disco", "Techno", "House", "Trance", "Dubstep",
        "Ambient", "Acoustic", "Latin", "Afrobeat",
        "Turkish Folk", "Turkish Classical", "Arabesque", "Anatolian Rock"
    ]
    let availablePlatforms = ["Spotify", "Apple Music", "YouTube Music"]
    
    func loadProfile(_ profile: Profile) {
        self.userName = profile.name
        self.wakeUpTime = profile.wakeUpTime
        self.selectedGenres = Set(profile.genres)
        self.selectedPlatform = profile.platform
    }
    
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            if selectedGenres.count < 3 {
                selectedGenres.insert(genre)
            }
        }
    }
    
    func saveSettings() async {
        isSaving = true
        let updatedProfile = Profile(
            name: userName,
            wakeUpTime: wakeUpTime,
            genres: Array(selectedGenres),
            platform: selectedPlatform
        )
        
        await SupabaseManager.shared.saveProfile(updatedProfile)
        isSaving = false
    }
}
