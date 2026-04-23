import Foundation
import UserNotifications
import UIKit
import Combine
import SwiftUI

/// Manages local notifications for morning suggestions
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    /// Schedules a local morning notification with a requested song suggestion
    func scheduleMorningNotification(at time: Date, suggestion: SongSuggestion, platform: String) {
        let content = UNMutableNotificationContent()
        content.title = "🎵 Günaydın! İşte Günün Şarkısı"
        content.body = "\(suggestion.message)\n\(suggestion.artist) - \(suggestion.title)"
        content.sound = .default
        
        // Include deep link data
        content.userInfo = [
            "title": suggestion.title,
            "artist": suggestion.artist,
            "platform": platform
        ]
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_suggestion", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully for \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                willPresent notification: UNNotification, 
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    
    // Handle tapping on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        
        if let title = userInfo["title"] as? String,
           let artist = userInfo["artist"] as? String,
           let platform = userInfo["platform"] as? String {
            
            openMusicApp(title: title, artist: artist, platform: platform)
        }
        
        completionHandler()
    }
    
    private func openMusicApp(title: String, artist: String, platform: String) {
        let query = "\(title) \(artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        var urlString = ""
        if platform == "Spotify" {
            urlString = "spotify:search:\(query)"
        } else if platform == "Apple Music" {
            // Apple Music url scheme trick
            urlString = "music://search?term=\(query)"
        }
        
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // Fallback to web search if app is not installed
            if let webURL = URL(string: "https://www.youtube.com/results?search_query=\(query)") {
                UIApplication.shared.open(webURL)
            }
        }
    }
}
