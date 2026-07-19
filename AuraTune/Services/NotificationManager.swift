import Foundation
@preconcurrency import UserNotifications
import UIKit
import Combine
import SwiftUI
import FirebaseAuth

/// Manages local notifications for morning suggestions
class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()

    enum DailyMusicScheduleStatus: Equatable {
        case checking
        case scheduled
        case permissionRequired
        case missing
        case failed
    }

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
    @Published private(set) var dailyMusicScheduleStatus: DailyMusicScheduleStatus = .checking
    @Published private(set) var dailyMusicScheduledComponents: DateComponents?

    private let dailyMusicIdentifier = "morning_suggestion"
    private let dailyMusicTestIdentifier = "daily_music_test"
    private let dailyMusicSoundFileName = "AuraTuneDailyV1.wav"
    private let waterSoundFileName = "AuraTuneWaterDropsV1.wav"
    private let waterSnoozeUnlockKey = "aura_waterSnoozeUnlocked"
    private let notificationSoundLock = NSLock()
    private var dailyMusicScheduleRevision = 0
    private var notificationMutationTask: Task<Void, Never>?

    private func storedDailySuggestionKey(for userID: String? = nil) -> String {
        let userID = userID ?? FirebaseManager.shared.currentUser?.uid ?? "signed-out"
        return "dailyMusicLastSuggestion.\(userID)"
    }

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
        static let dailyMusic = "DAILY_MUSIC"
        static let water = "WATER"
        static let medicine = "MEDICINE"
    }

    private enum DailyMusicAction {
        static let listen = "DAILY_MUSIC_ACTION_LISTEN"
    }

    private enum WaterAction {
        static let drank = "WATER_ACTION_DRANK"
        static let snooze = "WATER_ACTION_SNOOZE"
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
        _ = ensureDailyMusicNotificationSound()
        _ = ensureWaterNotificationSound()
    }
    
    func requestAuthorization(completion: ((Bool) -> Void)? = nil) {
        registerNotificationCategories()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
                DispatchQueue.main.async { completion?(false) }
                return
            }

            if granted {
                Task { @MainActor in
                    RemindersManager.shared.refreshAllReminderSchedules()
                    if let profile = FirebaseManager.shared.userProfile {
                        self.ensureDailyMusicNotification(for: profile)
                    }
                }
            }

            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func configureWaterRewardFeatures(snoozeUnlocked: Bool) {
        UserDefaults.standard.set(snoozeUnlocked, forKey: waterSnoozeUnlockKey)
        registerNotificationCategories()
    }

    private func registerNotificationCategories() {
        let isEnglish = LanguageManager.shared.currentLanguage == "en"

        let dailyMusicCategory = UNNotificationCategory(
            identifier: NotificationCategory.dailyMusic,
            actions: [
                UNNotificationAction(
                    identifier: DailyMusicAction.listen,
                    title: isEnglish ? "Continue on Platform" : "Platformda Devam Et",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        let drankAction = UNNotificationAction(
            identifier: WaterAction.drank,
            title: isEnglish ? "I Drank" : "İçtim",
            options: []
        )

        let skippedAction = UNNotificationAction(
            identifier: WaterAction.skipped,
            title: isEnglish ? "Not Now" : "Şimdi Değil",
            options: []
        )

        let snoozeAction = UNNotificationAction(
            identifier: WaterAction.snooze,
            title: isEnglish ? "In 15 Minutes" : "15 Dakika Sonra",
            options: []
        )

        var waterActions = [drankAction]
        if UserDefaults.standard.bool(forKey: waterSnoozeUnlockKey) {
            waterActions.append(snoozeAction)
        }
        waterActions.append(skippedAction)

        let waterCategory = UNNotificationCategory(
            identifier: NotificationCategory.water,
            actions: waterActions,
            intentIdentifiers: [],
            options: [.customDismissAction]
        )

        let medicineCategory = UNNotificationCategory(
            identifier: NotificationCategory.medicine,
            actions: [
                UNNotificationAction(
                    identifier: MedicineAction.took,
                    title: isEnglish ? "I Took It" : "Aldım",
                    options: []
                ),
                UNNotificationAction(
                    identifier: MedicineAction.skipped,
                    title: isEnglish ? "Skip" : "Atladım",
                    options: []
                )
            ],
            intentIdentifiers: [],
            options: []
        )

        UNUserNotificationCenter.current().setNotificationCategories([
            dailyMusicCategory,
            waterCategory,
            medicineCategory
        ])
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
    
    func ensureDailyMusicNotification(for profile: Profile, suggestion: SongSuggestion? = nil) {
        scheduleDailyMusicNotification(
            at: profile.wakeUpTime,
            suggestion: suggestion,
            platform: profile.platform
        )
    }

    /// Maintains one repeating request. A nil update preserves the last personalized song.
    func scheduleDailyMusicNotification(at time: Date, suggestion: SongSuggestion?, platform: String) {
        registerNotificationCategories()
        dailyMusicScheduleStatus = .checking
        dailyMusicScheduleRevision += 1
        let revision = dailyMusicScheduleRevision

        if let suggestion {
            storeDailySuggestion(suggestion)
        }

        let effectiveSuggestion = suggestion ?? storedDailySuggestion()
        let isEnglish = LanguageManager.shared.currentLanguage == "en"
        let hour = Calendar.current.component(.hour, from: time)
        let greetingText = greeting(for: hour, isEnglish: isEnglish)
        let content = dailyMusicContent(
            greeting: greetingText,
            suggestion: effectiveSuggestion,
            platform: platform,
            isEnglish: isEnglish
        )

        let components = Calendar.current.dateComponents([.hour, .minute], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyMusicIdentifier,
            content: content,
            trigger: trigger
        )

        enqueueNotificationMutation { [weak self] in
            guard let self, revision == self.dailyMusicScheduleRevision else { return }
            let center = UNUserNotificationCenter.current()
            let requests = await self.pendingNotificationRequests()
            guard revision == self.dailyMusicScheduleRevision else { return }

            let otherRequests = requests.filter { $0.identifier != self.dailyMusicIdentifier }
            let removalCount = max(0, otherRequests.count - 62)
            let prioritizedRemovals = otherRequests.sorted {
                self.removalPriority(for: $0.identifier) < self.removalPriority(for: $1.identifier)
            }
            let identifiersToRemove = [self.dailyMusicIdentifier]
                + prioritizedRemovals.prefix(removalCount).map(\.identifier)

            center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
            let error = await self.addNotificationRequest(request)
            guard revision == self.dailyMusicScheduleRevision else { return }

            if let error {
                self.dailyMusicScheduledComponents = nil
                self.dailyMusicScheduleStatus = .failed
                print("Daily music notification scheduling failed: \(error)")
            } else {
                self.refreshDailyMusicScheduleStatus()
                print("Daily music notification scheduled for \(components.hour ?? 0):\(components.minute ?? 0)")
            }
        }
    }

    func refreshDailyMusicScheduleStatus() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            center.getPendingNotificationRequests { requests in
                let dailyRequest = requests.first { $0.identifier == self.dailyMusicIdentifier }
                let scheduledComponents = (dailyRequest?.trigger as? UNCalendarNotificationTrigger)?.dateComponents

                Task { @MainActor in
                    self.dailyMusicScheduledComponents = scheduledComponents
                    switch settings.authorizationStatus {
                    case .authorized, .provisional, .ephemeral:
                        self.dailyMusicScheduleStatus = dailyRequest == nil ? .missing : .scheduled
                    case .denied, .notDetermined:
                        self.dailyMusicScheduleStatus = .permissionRequired
                    @unknown default:
                        self.dailyMusicScheduleStatus = .permissionRequired
                    }
                }
            }
        }
    }

    func scheduleDailyMusicTest(
        for profile: Profile,
        suggestion: SongSuggestion? = nil,
        completion: @escaping (Bool) -> Void
    ) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional
                    || settings.authorizationStatus == .ephemeral else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            let isEnglish = LanguageManager.shared.currentLanguage == "en"
            let content = self.dailyMusicContent(
                greeting: "AuraTune",
                suggestion: suggestion ?? self.storedDailySuggestion(),
                platform: profile.platform,
                isEnglish: isEnglish
            )
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
            let request = UNNotificationRequest(
                identifier: self.dailyMusicTestIdentifier,
                content: content,
                trigger: trigger
            )

            Task { @MainActor in
                self.enqueueNotificationMutation {
                    let center = UNUserNotificationCenter.current()
                    let requests = await self.pendingNotificationRequests()
                    let otherRequests = requests.filter {
                        $0.identifier != self.dailyMusicTestIdentifier
                            && $0.identifier != self.dailyMusicIdentifier
                    }
                    let removalCount = max(0, requests.count - 63)
                    let identifiersToRemove = [self.dailyMusicTestIdentifier]
                        + otherRequests.sorted {
                            self.removalPriority(for: $0.identifier) < self.removalPriority(for: $1.identifier)
                        }
                        .prefix(removalCount)
                        .map(\.identifier)

                    center.removePendingNotificationRequests(withIdentifiers: identifiersToRemove)
                    let error = await self.addNotificationRequest(request)
                    completion(error == nil)
                }
            }
        }
    }

    func cancelDailyMusicNotification(forUserID userID: String? = nil) {
        dailyMusicScheduleRevision += 1
        let identifiers = [dailyMusicIdentifier, dailyMusicTestIdentifier]
        UserDefaults.standard.removeObject(forKey: storedDailySuggestionKey(for: userID))
        enqueueNotificationMutation {
            let center = UNUserNotificationCenter.current()
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
            center.removeDeliveredNotifications(withIdentifiers: identifiers)
            self.dailyMusicScheduledComponents = nil
            self.dailyMusicScheduleStatus = .missing
        }
    }

    private func enqueueNotificationMutation(
        _ operation: @escaping @MainActor () async -> Void
    ) {
        let previousTask = notificationMutationTask
        notificationMutationTask = Task { @MainActor in
            await previousTask?.value
            await operation()
        }
    }

    private func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private func addNotificationRequest(_ request: UNNotificationRequest) async -> Error? {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { error in
                continuation.resume(returning: error)
            }
        }
    }

    private func removalPriority(for identifier: String) -> Int {
        if identifier == dailyMusicTestIdentifier { return 0 }
        if identifier.hasPrefix("water_") { return 1 }
        if identifier.hasPrefix("medicine_") { return 2 }
        return 3
    }

    private func dailyMusicContent(
        greeting: String,
        suggestion: SongSuggestion?,
        platform: String,
        isEnglish: Bool
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = isEnglish
            ? "\(greeting) • Your Daily Song"
            : "\(greeting) • Günün Şarkısı"

        if let suggestion {
            content.subtitle = "\(suggestion.title) • \(suggestion.artist)"
            content.body = suggestion.message
            content.userInfo = [
                "notificationType": "daily_music",
                "title": suggestion.title,
                "artist": suggestion.artist,
                "platform": platform
            ]
        } else {
            content.body = isEnglish
                ? "Your personalized song is waiting in AuraTune."
                : "Sana özel günün şarkısı AuraTune'da seni bekliyor."
            content.userInfo = [
                "notificationType": "daily_music",
                "platform": platform
            ]
        }

        content.sound = dailyMusicNotificationSound()
        content.categoryIdentifier = NotificationCategory.dailyMusic
        content.threadIdentifier = "daily-music"
        content.interruptionLevel = .active
        content.relevanceScore = 1
        return content
    }

    private func dailyMusicNotificationSound() -> UNNotificationSound {
        guard ensureDailyMusicNotificationSound() else { return .default }
        return UNNotificationSound(
            named: UNNotificationSoundName(rawValue: dailyMusicSoundFileName)
        )
    }

    private func ensureDailyMusicNotificationSound() -> Bool {
        ensureNotificationSound(
            fileName: dailyMusicSoundFileName,
            makeData: Self.makeDailyMusicSoundData
        )
    }

    private func waterNotificationSound() -> UNNotificationSound {
        guard ensureWaterNotificationSound() else { return .default }
        return UNNotificationSound(
            named: UNNotificationSoundName(rawValue: waterSoundFileName)
        )
    }

    private func ensureWaterNotificationSound() -> Bool {
        ensureNotificationSound(
            fileName: waterSoundFileName,
            makeData: Self.makeWaterSoundData
        )
    }

    private func ensureNotificationSound(
        fileName: String,
        makeData: () -> Data
    ) -> Bool {
        notificationSoundLock.lock()
        defer { notificationSoundLock.unlock() }

        let fileManager = FileManager.default
        guard let libraryDirectory = fileManager.urls(
            for: .libraryDirectory,
            in: .userDomainMask
        ).first else {
            return false
        }

        let soundsDirectory = libraryDirectory.appendingPathComponent("Sounds", isDirectory: true)
    let soundURL = soundsDirectory.appendingPathComponent(fileName)

        do {
            try fileManager.createDirectory(
                at: soundsDirectory,
                withIntermediateDirectories: true
            )

            if let attributes = try? fileManager.attributesOfItem(atPath: soundURL.path),
               let size = attributes[.size] as? NSNumber,
               size.intValue > 44 {
                return true
            }

            try makeData().write(to: soundURL, options: .atomic)
            return true
        } catch {
            print("Daily music notification sound preparation failed: \(error)")
            return false
        }
    }

    nonisolated private static func makeDailyMusicSoundData() -> Data {
        let sampleRate: UInt32 = 22_050
        let noteDuration = 0.46
        let trailingSilence = 0.25
        let frequencies: [Double] = [
            523.25, 659.25, 783.99, 987.77,
            880.00, 783.99, 659.25, 587.33,
            523.25, 659.25, 698.46, 880.00,
            783.99, 659.25, 587.33, 523.25
        ]
        let melodyDuration = Double(frequencies.count) * noteDuration
        let sampleCount = Int((melodyDuration + trailingSilence) * Double(sampleRate))

        var samples = Data()
        samples.reserveCapacity(sampleCount * MemoryLayout<Int16>.size)

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            let value: Double

            if time < melodyDuration {
                let noteIndex = min(Int(time / noteDuration), frequencies.count - 1)
                let noteTime = time - (Double(noteIndex) * noteDuration)
                let frequency = frequencies[noteIndex]
                let attack = min(1, noteTime / 0.025)
                let release = min(1, max(0, (noteDuration - noteTime) / 0.12))
                let envelope = attack * release
                let phase = 2 * Double.pi * frequency * noteTime
                let tone = sin(phase)
                    + (0.28 * sin(phase * 2))
                    + (0.18 * sin(phase * 0.5))
                value = tone * envelope * 0.32
            } else {
                value = 0
            }

            let clamped = max(-1, min(1, value))
            appendLittleEndian(Int16(clamped * Double(Int16.max)), to: &samples)
        }

        return makeWaveData(samples: samples, sampleRate: sampleRate)
    }

    nonisolated private static func makeWaterSoundData() -> Data {
        let sampleRate: UInt32 = 22_050
        let duration = 3.8
        let sampleCount = Int(duration * Double(sampleRate))
        let drops: [(time: Double, frequency: Double)] = [
            (0.18, 1_480),
            (0.74, 1_180),
            (1.36, 1_620),
            (2.08, 1_280),
            (2.72, 1_520),
            (3.24, 1_080)
        ]

        var samples = Data()
        samples.reserveCapacity(sampleCount * MemoryLayout<Int16>.size)
        var randomState: UInt32 = 0xA17A_7E11
        var smoothedNoise = 0.0

        for sampleIndex in 0..<sampleCount {
            let time = Double(sampleIndex) / Double(sampleRate)
            randomState = 1_664_525 &* randomState &+ 1_013_904_223
            let whiteNoise = (Double(randomState) / Double(UInt32.max) * 2) - 1
            smoothedNoise = (smoothedNoise * 0.965) + (whiteNoise * 0.035)
            var value = smoothedNoise * 0.14

            for drop in drops {
                let elapsed = time - drop.time
                guard elapsed >= 0, elapsed < 0.34 else { continue }
                let attack = 1 - exp(-95 * elapsed)
                let decay = exp(-15 * elapsed)
                let sweep = drop.frequency * 0.72
                let phase = 2 * Double.pi * (
                    drop.frequency * elapsed - (sweep * elapsed * elapsed / 0.68)
                )
                value += sin(phase) * attack * decay * 0.58
            }

            let fadeIn = min(1, time / 0.08)
            let fadeOut = min(1, max(0, (duration - time) / 0.28))
            let clamped = max(-1, min(1, value * fadeIn * fadeOut))
            appendLittleEndian(Int16(clamped * Double(Int16.max)), to: &samples)
        }

        return makeWaveData(samples: samples, sampleRate: sampleRate)
    }

    nonisolated private static func makeWaveData(samples: Data, sampleRate: UInt32) -> Data {
        let dataSize = UInt32(samples.count)
        var wave = Data()
        wave.reserveCapacity(44 + samples.count)
        wave.append(contentsOf: "RIFF".utf8)
        appendLittleEndian(UInt32(36) + dataSize, to: &wave)
        wave.append(contentsOf: "WAVE".utf8)
        wave.append(contentsOf: "fmt ".utf8)
        appendLittleEndian(UInt32(16), to: &wave)
        appendLittleEndian(UInt16(1), to: &wave)
        appendLittleEndian(UInt16(1), to: &wave)
        appendLittleEndian(sampleRate, to: &wave)
        appendLittleEndian(sampleRate * UInt32(MemoryLayout<Int16>.size), to: &wave)
        appendLittleEndian(UInt16(MemoryLayout<Int16>.size), to: &wave)
        appendLittleEndian(UInt16(16), to: &wave)
        wave.append(contentsOf: "data".utf8)
        appendLittleEndian(dataSize, to: &wave)
        wave.append(samples)
        return wave
    }

    nonisolated private static func appendLittleEndian<Value: FixedWidthInteger>(
        _ value: Value,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    private func storeDailySuggestion(_ suggestion: SongSuggestion) {
        guard let data = try? JSONEncoder().encode(suggestion) else { return }
        UserDefaults.standard.set(data, forKey: storedDailySuggestionKey())
    }

    private func storedDailySuggestion() -> SongSuggestion? {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: storedDailySuggestionKey()),
           let suggestion = try? JSONDecoder().decode(SongSuggestion.self, from: data) {
            return suggestion
        }

        return nil
    }

    // MARK: - Water Reminders

    func scheduleWaterReminders(
        startTime: Date,
        endTime: Date,
        intervalMinutes: Int,
        dailyGoalLiters: Double,
        messages: [String] = [],
        glassesToday: Int = 0,
        showsGoalProgress: Bool = false
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

        var slotMinutes: [Int] = []
        var current = startTotal
        while current <= endTotal {
            slotMinutes.append(current)
            current += effectiveInterval
        }

        let scheduledMessages = makeWaterMessageSchedule(
            slotHours: slotMinutes.map { $0 / 60 },
            aiMessages: validatedMessages,
            isEnglish: isEnglish,
            dailyGoalLiters: dailyGoalLiters
        )

        for (index, totalMinutes) in slotMinutes.enumerated() {
            let hour = totalMinutes / 60
            let minute = totalMinutes % 60

            let content = UNMutableNotificationContent()
            content.title = waterReminderTitle(hour: hour, index: index, isEnglish: isEnglish)
            let baseMessage = scheduledMessages[index]
            content.body = waterReminderMessage(
                baseMessage: baseMessage,
                isEnglish: isEnglish,
                dailyGoalLiters: dailyGoalLiters,
                glassesToday: glassesToday,
                showsGoalProgress: showsGoalProgress,
                variationIndex: index
            )

            content.sound = waterNotificationSound()
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
        }
        print("Scheduled \(slotMinutes.count) water reminders every \(effectiveInterval) min.")
    }

    private enum WaterMessagePeriod {
        case morning
        case afternoon
        case evening
    }

    private func makeWaterMessageSchedule(
        slotHours: [Int],
        aiMessages: [String],
        isEnglish: Bool,
        dailyGoalLiters: Double
    ) -> [String] {
        var generalDeck = orderedUniqueMessages(
            aiMessages + curatedGeneralWaterMessages(
                isEnglish: isEnglish,
                dailyGoalLiters: dailyGoalLiters
            )
        ).shuffled()
        var periodDecks: [WaterMessagePeriod: [String]] = [
            .morning: curatedWaterMessages(for: .morning, isEnglish: isEnglish).shuffled(),
            .afternoon: curatedWaterMessages(for: .afternoon, isEnglish: isEnglish).shuffled(),
            .evening: curatedWaterMessages(for: .evening, isEnglish: isEnglish).shuffled()
        ]

        var result: [String] = []
        var usedKeys = Set<String>()
        var previousKey: String?

        for (index, hour) in slotHours.enumerated() {
            let period = waterMessagePeriod(for: hour)
            let periodDeck = periodDecks[period] ?? []
            let candidates = index.isMultiple(of: 3)
                ? generalDeck + periodDeck
                : periodDeck + generalDeck

            var selected = candidates.first { candidate in
                let key = normalizedMessageKey(candidate)
                return key != previousKey && !usedKeys.contains(key)
            }

            if selected == nil {
                usedKeys.removeAll()
                selected = candidates.first { normalizedMessageKey($0) != previousKey }
            }

            let message = selected ?? defaultWaterMessage(
                isEnglish: isEnglish,
                dailyGoalLiters: dailyGoalLiters
            )
            let key = normalizedMessageKey(message)
            usedKeys.insert(key)
            previousKey = key
            result.append(message)

            if let generalIndex = generalDeck.firstIndex(of: message) {
                generalDeck.append(generalDeck.remove(at: generalIndex))
            } else if let periodIndex = periodDecks[period]?.firstIndex(of: message) {
                let moved = periodDecks[period]?.remove(at: periodIndex)
                if let moved {
                    periodDecks[period]?.append(moved)
                }
            }
        }

        return result
    }

    private func waterMessagePeriod(for hour: Int) -> WaterMessagePeriod {
        switch hour {
        case ..<12: return .morning
        case 12..<18: return .afternoon
        default: return .evening
        }
    }

    private func waterReminderTitle(hour: Int, index: Int, isEnglish: Bool) -> String {
        let titles: [String]
        switch waterMessagePeriod(for: hour) {
        case .morning:
            titles = isEnglish
                ? ["💧 A Fresh Start", "☀️ Morning Water Break", "💙 Start with a Sip"]
                : ["💧 Ferah Bir Başlangıç", "☀️ Sabah Su Molası", "💙 Güne Bir Yudum"]
        case .afternoon:
            titles = isEnglish
                ? ["💧 Water Break", "🌿 A Small Refresh", "🥛 Time for a Glass"]
                : ["💧 Su Molası", "🌿 Küçük Bir Ferahlık", "🥛 Bir Bardak Zamanı"]
        case .evening:
            titles = isEnglish
                ? ["💧 Evening Sip", "🌙 A Gentle Reminder", "✨ Finish the Day Fresh"]
                : ["💧 Akşam Yudumu", "🌙 Nazik Bir Hatırlatma", "✨ Günü Ferah Tamamla"]
        }
        return titles[index % titles.count]
    }

    private func waterReminderMessage(
        baseMessage: String,
        isEnglish: Bool,
        dailyGoalLiters: Double,
        glassesToday: Int,
        showsGoalProgress: Bool,
        variationIndex: Int
    ) -> String {
        guard showsGoalProgress else { return baseMessage }

        let goalGlasses = max(1, Int((dailyGoalLiters / 0.25).rounded()))
        let remaining = max(0, goalGlasses - glassesToday)
        if remaining == 0 {
            let completed = isEnglish
                ? [
                    "Today's goal is complete. Sip whenever you feel you need it.",
                    "Goal reached for today. Anything more is simply a gentle extra.",
                    "You completed today's plan. Keep your glass nearby if you like."
                ]
                : [
                    "Bugünkü hedef tamam. İhtiyaç duydukça yudumlamaya devam edebilirsin.",
                    "Hedefe ulaştın. Bundan sonrası yalnızca nazik bir ek.",
                    "Bugünün planı tamamlandı. Dilersen bardağını yanında tut."
                ]
            return completed[variationIndex % completed.count]
        }

        let progressOptions = isEnglish
            ? [
                "\(remaining) glasses remain for today's goal.",
                "You're \(remaining) glasses away from today's plan.",
                "Just \(remaining) more glasses to complete today's rhythm.",
                "Today's plan has room for \(remaining) more glasses."
            ]
            : [
                "Bugünkü hedefe \(remaining) bardak kaldı.",
                "Günün planını tamamlamana \(remaining) bardak var.",
                "Bugünkü ritim için yalnızca \(remaining) bardak daha.",
                "Günün planında \(remaining) bardaklık yer kaldı."
            ]
        let progress = progressOptions[variationIndex % progressOptions.count]
        return "\(baseMessage) \(progress)"
    }

    private func orderedUniqueMessages(_ messages: [String]) -> [String] {
        var seen = Set<String>()
        return messages.filter { seen.insert(normalizedMessageKey($0)).inserted }
    }

    private func normalizedMessageKey(_ message: String) -> String {
        normalizeMessage(message).lowercased()
    }

    private func curatedGeneralWaterMessages(
        isEnglish: Bool,
        dailyGoalLiters: Double
    ) -> [String] {
        let litersText = String(format: "%.1f", dailyGoalLiters)
        if isEnglish {
            return [
                "A few calm sips can fit into even the busiest minute. 💧",
                "Keep your glass within reach and let the next sip come naturally. 🌿",
                "Pause, breathe, and make a little room for water. 💙",
                "No rush, no pressure; this is simply your water moment. ✨",
                "One glass at a time is enough to keep a steady rhythm. 🥛",
                "A tiny pause for water can reset the pace of your day. 💧",
                "Your \(litersText)L plan is built one easy glass at a time. 🌊",
                "Refill the glass, take a sip, and return to your day. 🌱",
                "Let this be the quietest task on your list: a little water. 💙",
                "Your bottle is nearby for a reason. Give it a quick visit. 💧",
                "Small routines feel lighter when they begin with one sip. ✨",
                "Take the kind of water break that asks for only a moment. 🌿"
            ]
        }

        return [
            "En yoğun dakikaya bile birkaç sakin yudum sığar. 💧",
            "Bardağın yakınında olsun; sıradaki yudum kendiliğinden gelsin. 🌿",
            "Kısa bir durak, derin bir nefes ve biraz su. 💙",
            "Acele yok, baskı yok; bu yalnızca senin su molan. ✨",
            "Düzenli bir ritim için her seferinde tek bardak yeter. 🥛",
            "Küçük bir su molası günün temposunu nazikçe yeniler. 💧",
            "\(litersText) litrelik planın, kolay bardaklarla adım adım tamamlanır. 🌊",
            "Bardağı doldur, bir yudum al ve gününe kaldığın yerden dön. 🌱",
            "Listenin en sakin işi: şimdi biraz su. 💙",
            "Şişen yakınındaysa, kısa bir yudum ziyareti zamanı. 💧",
            "Küçük alışkanlıklar tek bir yudumla daha kolay başlar. ✨",
            "Yalnızca bir an isteyen, sakin bir su molası ver. 🌿"
        ]
    }

    private func curatedWaterMessages(
        for period: WaterMessagePeriod,
        isEnglish: Bool
    ) -> [String] {
        switch (period, isEnglish) {
        case (.morning, true):
            return [
                "Begin the day gently with a fresh glass of water. ☀️",
                "Before the pace picks up, give yourself a quiet sip. 💧",
                "Make a little space for water alongside your morning routine. 🌤️",
                "Fill your glass now and keep the morning rhythm easy. 💙",
                "A bright morning pairs well with a simple water break. ✨",
                "Set your bottle nearby before the day gets busy. 🌿",
                "Morning light, a clear glass, and one unhurried sip. 💧",
                "Start small: one glass, then carry on with your morning. 🥛"
            ]
        case (.morning, false):
            return [
                "Güne taze bir bardak suyla sakince başla. ☀️",
                "Tempo yükselmeden önce kendine kısa bir yudum ayır. 💧",
                "Sabah düzeninde suya da küçük bir yer aç. 🌤️",
                "Bardağını şimdi doldur, sabah ritmin kolay aksın. 💙",
                "Aydınlık bir sabaha sade bir su molası yakışır. ✨",
                "Gün yoğunlaşmadan şişeni yakınına al. 🌿",
                "Sabah ışığı, berrak bir bardak ve acele etmeyen bir yudum. 💧",
                "Küçük başla: bir bardak su, sonra sabahına devam et. 🥛"
            ]
        case (.afternoon, true):
            return [
                "Step away from the afternoon rush for one easy glass. 🌿",
                "A short water break belongs between today's busy moments. 💧",
                "Refill, take a sip, and return with a gentler pace. 💙",
                "Let your next small break be a water break. 🥛",
                "The afternoon is moving; keep your glass moving too. ✨",
                "Put the screen down for a moment and pick the glass up. 💧",
                "A calm sip is a simple pause in the middle of the day. 🌤️",
                "Keep the day's rhythm steady with a fresh refill. 🌊"
            ]
        case (.afternoon, false):
            return [
                "Öğleden sonranın temposundan bir bardaklık uzaklaş. 🌿",
                "Günün yoğun anları arasına kısa bir su molası ekle. 💧",
                "Bardağı yenile, bir yudum al ve daha sakin devam et. 💙",
                "Sıradaki küçük molan, su molası olsun. 🥛",
                "Öğleden sonra ilerliyor; bardağın da sana eşlik etsin. ✨",
                "Ekranı bir an bırak, bardağı eline al. 💧",
                "Sakin bir yudum, günün ortasında sade bir duraktır. 🌤️",
                "Taze bir dolumla günün ritmini dengede tut. 🌊"
            ]
        case (.evening, true):
            return [
                "Slow the evening down with a gentle sip. 🌙",
                "Before the day wraps up, make room for a little water. 💧",
                "Keep the evening easy with your glass close by. ✨",
                "One quiet refill can be part of winding down. 🌿",
                "Take an unhurried sip as the day settles. 💙",
                "Your evening routine has room for one simple glass. 🥛",
                "End the busy part of the day with a calm water break. 🌙",
                "A final gentle reminder: check in with your water bottle. 💧"
            ]
        case (.evening, false):
            return [
                "Akşamın temposunu sakin bir yudumla yavaşlat. 🌙",
                "Gün tamamlanmadan biraz suya yer aç. 💧",
                "Bardağın yakınında olsun, akşamın kolay aksın. ✨",
                "Sakinleşme ritmine küçük bir su molası ekle. 🌿",
                "Gün durulurken acele etmeden bir yudum al. 💙",
                "Akşam düzeninde sade bir bardak suya da yer var. 🥛",
                "Günün yoğun kısmını sakin bir su molasıyla kapat. 🌙",
                "Son bir nazik hatırlatma: su şişene uğramayı unutma. 💧"
            ]
        }
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
        guard !message.isEmpty, message.count <= 115 else { return false }
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
                } else if actionID == WaterAction.snooze {
                    self.scheduleWaterSnooze(from: content)
                    RemindersManager.shared.handleWaterNotificationAction(didDrink: false)
                } else if actionID == WaterAction.skipped {
                    RemindersManager.shared.handleWaterNotificationAction(didDrink: false)
                }
                completionHandler()
            }
            return
        }

        if categoryID == NotificationCategory.medicine {
            Task { @MainActor in
                if actionID == MedicineAction.took {
                    RemindersManager.shared.handleMedicineNotificationAction(tookMedicine: true)
                } else if actionID == MedicineAction.skipped {
                    RemindersManager.shared.handleMedicineNotificationAction(tookMedicine: false)
                }
                completionHandler()
            }
            return
        }

        if categoryID == NotificationCategory.dailyMusic {
            if actionID == UNNotificationDefaultActionIdentifier || actionID == DailyMusicAction.listen {
                openMusicFromNotification(content.userInfo)
            }
            completionHandler()
            return
        }
        
        let userInfo = response.notification.request.content.userInfo
        
        openMusicFromNotification(userInfo)
        
        completionHandler()
    }

    func handleForegroundWaterAction(didDrink: Bool) {
        Task { @MainActor in
            RemindersManager.shared.handleWaterNotificationAction(didDrink: didDrink)
            foregroundPrompt = nil
        }
    }

    func snoozeForegroundWaterReminder() {
        guard let prompt = foregroundPrompt, prompt.type == .water else { return }
        scheduleWaterSnooze(
            title: prompt.title,
            body: prompt.body,
            userInfo: ["notificationType": "water"]
        )
        Task { @MainActor in
            RemindersManager.shared.handleWaterNotificationAction(didDrink: false)
            foregroundPrompt = nil
        }
    }

    func handleForegroundMedicineAction(tookMedicine: Bool) {
        Task { @MainActor in
            RemindersManager.shared.handleMedicineNotificationAction(tookMedicine: tookMedicine)
            foregroundPrompt = nil
        }
    }

    func dismissForegroundPrompt() {
        Task { @MainActor in
            foregroundPrompt = nil
        }
    }

    private func scheduleWaterSnooze(from content: UNNotificationContent) {
        scheduleWaterSnooze(
            title: content.title,
            body: content.body,
            userInfo: content.userInfo
        )
    }

    private func scheduleWaterSnooze(
        title: String,
        body: String,
        userInfo: [AnyHashable: Any]
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = waterNotificationSound()
        content.categoryIdentifier = NotificationCategory.water
        content.userInfo = userInfo

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 15 * 60, repeats: false)
        let request = UNNotificationRequest(
            identifier: "water_snooze_\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func openMusicFromNotification(_ userInfo: [AnyHashable: Any]) {
        guard let title = userInfo["title"] as? String,
              let artist = userInfo["artist"] as? String,
              let platform = userInfo["platform"] as? String else { return }

        Task {
            let resolved = await MusicPlaybackResolver.shared.resolvePlaybackURLs(
                title: title,
                artist: artist,
                platform: platform
            )

            if let appURL = resolved.appURL, UIApplication.shared.canOpenURL(appURL) {
                await UIApplication.shared.open(appURL)
                return
            }

            if let webURL = resolved.webURL {
                await UIApplication.shared.open(webURL)
            }
        }
    }
}
