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
    @Published var hasChanges = false

    private var originalName: String = ""
    private var originalTime: Date = Date()
    private var originalGenres: Set<String> = []
    private var originalPlatform: String = "Spotify"
    
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
        // Store originals
        self.originalName = profile.name
        self.originalTime = profile.wakeUpTime
        self.originalGenres = Set(profile.genres)
        self.originalPlatform = profile.platform
        self.hasChanges = false
    }

    func checkChanges() {
        hasChanges = userName != originalName
            || selectedPlatform != originalPlatform
            || selectedGenres != originalGenres
            || abs(wakeUpTime.timeIntervalSince(originalTime)) > 60
    }
    
    func toggleGenre(_ genre: String) {
        if selectedGenres.contains(genre) {
            selectedGenres.remove(genre)
        } else {
            if selectedGenres.count < 10 {
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

        // Re-schedule the morning notification at the (possibly new) wake-up time.
        NotificationManager.shared.scheduleMorningNotification(
            at: wakeUpTime,
            suggestion: nil,
            platform: selectedPlatform
        )

        // Reset originals after save
        originalName = userName
        originalTime = wakeUpTime
        originalGenres = selectedGenres
        originalPlatform = selectedPlatform
        hasChanges = false
        isSaving = false
    }
}
