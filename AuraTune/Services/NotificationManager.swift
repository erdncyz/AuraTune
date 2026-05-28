import Foundation
import UserNotifications
import UIKit
import Combine
import SwiftUI

/// Manages local notifications for morning suggestions
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    enum ForegroundPromptType {
        case water
        case medicine
    }

    enum ForegroundPromptOrigin {
        case foregroundDelivery
        case notificationTap
    }

    struct ForegroundPrompt: Identifiable {
        let id = UUID()
        let type: ForegroundPromptType
        let origin: ForegroundPromptOrigin
        let title: String
        let body: String
    }

    @Published var foregroundPrompt: ForegroundPrompt?

    private func publishPrompt(from content: UNNotificationContent, type: ForegroundPromptType, origin: ForegroundPromptOrigin) {
        DispatchQueue.main.async {
            self.foregroundPrompt = ForegroundPrompt(
                type: type,
                origin: origin,
                title: content.title,
                body: content.body
            )
        }
    }

    private enum NotificationCategory {
        static let water = "WATER"
        static let medicine = "MEDICINE"
    }

    private enum WaterAction {
        static let drank = "WATER_ACTION_DRANK"
        static let skipped = "WATER_ACTION_SKIPPED"
    }

    private enum MedicineAction {
        static let took = "MEDICINE_ACTION_TOOK"
        static let skipped = "MEDICINE_ACTION_SKIPPED"
    }
    
    override private init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        registerNotificationCategories()
    }
    
    func requestAuthorization() {
        registerNotificationCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
                return
            }

            if granted {
                Task { @MainActor in
                    RemindersManager.shared.refreshAllReminderSchedules()
                }
            }
        }
    }

    private func registerNotificationCategories() {
        let isEnglish = LanguageManager.shared.currentLanguage == "en"

        let drankAction = UNNotificationAction(
            identifier: WaterAction.drank,
            title: isEnglish ? "I Drank" : "Ictim",
            options: []
        )

        let skippedAction = UNNotificationAction(
            identifier: WaterAction.skipped,
            title: isEnglish ? "Not Yet" : "Icmedim",
            options: []
        )

        let waterCategory = UNNotificationCategory(
            identifier: NotificationCategory.water,
            actions: [drankAction, skippedAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let medicineCategory = UNNotificationCategory(
            identifier: NotificationCategory.medicine,
            actions: [
                UNNotificationAction(
                    identifier: MedicineAction.took,
                    title: isEnglish ? "I Took It" : "Aldim",
                    options: []
                ),
                UNNotificationAction(
                    identifier: MedicineAction.skipped,
                    title: isEnglish ? "Skip" : "Atladim",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([waterCategory, medicineCategory])
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
        registerNotificationCategories()
        cancelWaterReminders()
        let isEnglish = LanguageManager.shared.currentLanguage == "en"
        let validatedMessages = sanitizeWaterMessages(
            messages,
            isEnglish: isEnglish,
            dailyGoalLiters: dailyGoalLiters
        )
        let effectiveInterval = max(15, intervalMinutes)

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
            if !validatedMessages.isEmpty {
                content.body = validatedMessages[index % validatedMessages.count]
            } else {
                content.body = defaultWaterMessage(
                    isEnglish: isEnglish,
                    dailyGoalLiters: dailyGoalLiters
                )
            }

            content.sound = .default
            content.categoryIdentifier = NotificationCategory.water
            content.userInfo = ["notificationType": "water"]

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

            current += effectiveInterval
            index += 1
        }
        print("Scheduled \(index) water reminders every \(effectiveInterval) min.")
    }

    private func defaultWaterMessage(isEnglish: Bool, dailyGoalLiters: Double) -> String {
        let glasses = max(1, Int((dailyGoalLiters / 0.25).rounded()))
        let litersText = String(format: "%.1f", dailyGoalLiters)

        if isEnglish {
            return "Your daily target is \(litersText)L (~\(glasses) glasses). Drink a glass now. 💙"
        }

        return "Günlük hedefin \(litersText)L (~\(glasses) bardak). Şimdi bir bardak su iç. 💙"
    }

    private func sanitizeWaterMessages(
        _ messages: [String],
        isEnglish: Bool,
        dailyGoalLiters: Double
    ) -> [String] {
        var unique: [String] = []

        for raw in messages {
            let cleaned = normalizeMessage(raw)
            guard isValidWaterMessage(cleaned, isEnglish: isEnglish) else { continue }
            if !unique.contains(cleaned) {
                unique.append(cleaned)
            }
        }

        if unique.isEmpty {
            return []
        }

        let fallback = defaultWaterMessage(isEnglish: isEnglish, dailyGoalLiters: dailyGoalLiters)
        return unique.map { $0.isEmpty ? fallback : $0 }
    }

    private func normalizeMessage(_ message: String) -> String {
        message
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+([,.;:!?])", with: "$1", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isValidWaterMessage(_ message: String, isEnglish: Bool) -> Bool {
        guard !message.isEmpty, message.count <= 140 else { return false }
        guard !containsUnexpectedScript(in: message) else { return false }

        let lower = message.lowercased()

        if isEnglish {
            // If Turkish-specific letters are present in an English sentence, treat it as mixed language.
            let turkishChars = CharacterSet(charactersIn: "çğıöşü")
            if lower.rangeOfCharacter(from: turkishChars) != nil {
                return false
            }
            return true
        }

        let obviousEnglishWords: Set<String> = [
            "drink", "water", "healthy", "goal", "daily", "hydration", "glass", "glasses",
            "body", "energy", "focus", "today", "remember", "time", "keep", "now"
        ]

        let words = lower
            .split(whereSeparator: { !$0.isLetter })
            .map(String.init)

        let englishWordCount = words.reduce(0) { partial, word in
            partial + (obviousEnglishWords.contains(word) ? 1 : 0)
        }

        return englishWordCount == 0
    }

    private func containsUnexpectedScript(in text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
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
        registerNotificationCategories()
        let isEnglish = LanguageManager.shared.currentLanguage == "en"
        let calendar = Calendar.current

        for (index, time) in medicine.times.enumerated() {
            let content = UNMutableNotificationContent()
            content.title = "💊 \(medicine.name)"
            content.body = isEnglish
                ? "Time to take: \(medicine.dose)"
                : "İlaç alma zamanı: \(medicine.dose)"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.medicine

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
        let content = notification.request.content
        let categoryID = content.categoryIdentifier

        if categoryID == NotificationCategory.water {
            publishPrompt(from: content, type: .water, origin: .foregroundDelivery)
            completionHandler([.banner, .sound])
            return
        }

        if categoryID == NotificationCategory.medicine {
            publishPrompt(from: content, type: .medicine, origin: .foregroundDelivery)
            completionHandler([.banner, .sound])
            return
        }

        completionHandler([.banner, .sound])
    }
    
    // Handle tapping on the notification
    func userNotificationCenter(_ center: UNUserNotificationCenter, 
                                didReceive response: UNNotificationResponse, 
                                withCompletionHandler completionHandler: @escaping () -> Void) {

        let categoryID = response.notification.request.content.categoryIdentifier
        let actionID = response.actionIdentifier
        let content = response.notification.request.content

        // User tapped the notification itself (not an action button)
        if actionID == UNNotificationDefaultActionIdentifier {
            if categoryID == NotificationCategory.water {
                publishPrompt(from: content, type: .water, origin: .notificationTap)
                completionHandler()
                return
            }

            if categoryID == NotificationCategory.medicine {
                publishPrompt(from: content, type: .medicine, origin: .notificationTap)
                completionHandler()
                return
            }
        }

        if categoryID == NotificationCategory.water {
            Task { @MainActor in
                if actionID == WaterAction.drank {
                    RemindersManager.shared.handleWaterNotificationAction(didDrink: true)
                } else if actionID == WaterAction.skipped {
                    RemindersManager.shared.handleWaterNotificationAction(didDrink: false)
                }
                completionHandler()
            }
            return
        }

        if categoryID == NotificationCategory.medicine {
            // Reserve for medicine adherence tracking in future.
            if actionID == MedicineAction.took {
                print("[NotificationManager] Medicine action: took")
            } else if actionID == MedicineAction.skipped {
                print("[NotificationManager] Medicine action: skipped")
            }
            completionHandler()
            return
        }
        
        let userInfo = response.notification.request.content.userInfo
        
        if let title = userInfo["title"] as? String,
           let artist = userInfo["artist"] as? String,
           let platform = userInfo["platform"] as? String {
            
            openMusicApp(title: title, artist: artist, platform: platform)
        }
        
        completionHandler()
    }

    func handleForegroundWaterAction(didDrink: Bool) {
        Task { @MainActor in
            RemindersManager.shared.handleWaterNotificationAction(didDrink: didDrink)
            foregroundPrompt = nil
        }
    }

    func handleForegroundMedicineAction(tookMedicine: Bool) {
        if tookMedicine {
            print("[NotificationManager] Foreground medicine action: took")
        } else {
            print("[NotificationManager] Foreground medicine action: skipped")
        }
        Task { @MainActor in
            foregroundPrompt = nil
        }
    }

    func dismissForegroundPrompt() {
        Task { @MainActor in
            foregroundPrompt = nil
        }
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
