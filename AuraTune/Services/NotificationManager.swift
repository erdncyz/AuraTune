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

    private func greeting(for hour: Int, isEnglish: Bool) -> String {
        if isEnglish {
            switch hour {
            case 5..<12:  return "Good Morning ☀️"
            case 12..<17: return "Good Afternoon ⛅"
            case 17..<21: return "Good Evening ✨"
            default:      return "Good Night 🌙"
            }
        }

        switch hour {
        case 5..<12:  return "Günaydın ☀️"
        case 12..<17: return "İyi Öğlenler ⛅"
        case 17..<21: return "İyi Akşamlar ✨"
        default:      return "İyi Geceler 🌙"
        }
    }
    
    /// Schedules a local morning notification with an optional song suggestion
    func scheduleMorningNotification(at time: Date, suggestion: SongSuggestion?, platform: String) {
        let isEnglish = LanguageManager.shared.currentLanguage == "en"
        let hour = Calendar.current.component(.hour, from: time)
        let greetingText = greeting(for: hour, isEnglish: isEnglish)

        let content = UNMutableNotificationContent()
        content.title = isEnglish
            ? "\(greetingText) • Your Daily Song"
            : "\(greetingText) • Günün Şarkısı"
        if let suggestion = suggestion {
            content.body = "\(suggestion.message)\n\(suggestion.artist) - \(suggestion.title)"
            content.userInfo = [
                "title": suggestion.title,
                "artist": suggestion.artist,
                "platform": platform
            ]
        } else {
            content.body = isEnglish
                ? "Open AuraTune to discover today's song."
                : "Günün şarkısını keşfetmek için AuraTune'u aç."
            content.userInfo = ["platform": platform]
        }
        content.sound = .default
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "morning_suggestion", content: content, trigger: trigger)

        // Replace any existing scheduled notification before adding the new one
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["morning_suggestion"])

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                print("Notification scheduled successfully for \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }

    // MARK: - Water Reminders

    func scheduleWaterReminders(
        startTime: Date,
        endTime: Date,
        intervalMinutes: Int,
        dailyGoalLiters: Double,
        messages: [String] = []
    ) {
        cancelWaterReminders()
        let isEnglish = LanguageManager.shared.currentLanguage == "en"

        let calendar = Calendar.current
        let startComps = calendar.dateComponents([.hour, .minute], from: startTime)
        let endComps = calendar.dateComponents([.hour, .minute], from: endTime)
        let startTotal = (startComps.hour ?? 8) * 60 + (startComps.minute ?? 0)
        let endTotal = (endComps.hour ?? 22) * 60 + (endComps.minute ?? 0)

        var current = startTotal
        var index = 0

        while current <= endTotal {
            let hour = current / 60
            let minute = current % 60

            let content = UNMutableNotificationContent()
            content.title = isEnglish ? "💧 Time to Drink Water" : "💧 Su İçme Vakti"

            // Use AI-generated motivation message if available, cycle through them
            if !messages.isEmpty {
                content.body = messages[index % messages.count]
            } else {
                content.body = defaultWaterMessage(
                    isEnglish: isEnglish,
                    dailyGoalLiters: dailyGoalLiters
                )
            }

            content.sound = .default
            content.categoryIdentifier = "WATER"

            var comps = DateComponents()
            comps.hour = hour
            comps.minute = minute

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: String(format: "water_%02d_%02d", hour, minute),
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)

            current += intervalMinutes
            index += 1
        }
        print("Scheduled \(index) water reminders every \(intervalMinutes) min.")
    }

    private func defaultWaterMessage(isEnglish: Bool, dailyGoalLiters: Double) -> String {
        let glasses = max(1, Int((dailyGoalLiters / 0.25).rounded()))
        let litersText = String(format: "%.1f", dailyGoalLiters)

        if isEnglish {
            return "Your daily target is \(litersText)L (~\(glasses) glasses). Drink a glass now. 💙"
        }

        return "Gunluk hedefin \(litersText) L (~\(glasses) bardak). Simdi bir bardak su ic. 💙"
    }

    func cancelWaterReminders() {
        let ids = allWaterReminderIdentifiers()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ids)
    }

    private func allWaterReminderIdentifiers() -> [String] {
        var ids: [String] = []
        ids.reserveCapacity(24 * 60)
        for hour in 0..<24 {
            for minute in 0..<60 {
                ids.append(String(format: "water_%02d_%02d", hour, minute))
            }
        }
        return ids
    }

    // MARK: - Medicine Reminders

    func scheduleMedicineReminders(_ medicine: MedicineReminder) {
        let isEnglish = LanguageManager.shared.currentLanguage == "en"
        let calendar = Calendar.current

        for (index, time) in medicine.times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "💊 \(medicine.name)"
            content.body = isEnglish
                ? "Time to take: \(medicine.dose)"
                : "İlaç alma zamanı: \(medicine.dose)"
            content.sound = .default
            content.categoryIdentifier = "MEDICINE"

            let comps = calendar.dateComponents([.hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
            let request = UNNotificationRequest(
                identifier: "medicine_\(medicine.id.uuidString)_\(index)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelMedicineReminders(id: UUID) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let prefix = "medicine_\(id.uuidString)"
            let ids = requests
                .filter { $0.identifier.hasPrefix(prefix) }
                .map { $0.identifier }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
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
