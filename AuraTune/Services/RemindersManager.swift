import Foundation
import SwiftUI
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - Water Settings
struct WaterSettings: Codable {
    var isEnabled: Bool = false
    var intervalMinutes: Int = 60
    var startTime: Date = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    var endTime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    /// User-selected daily water goal in liters (e.g. 2.0 = 2 litres)
    var dailyGoalLiters: Double = 2.0
    var glassesToday: Int = 0
    var lastLogDate: Date = Date.distantPast

    /// 1 glass = 250 ml = 0.25 L
    var dailyGoalGlasses: Int { max(1, Int((dailyGoalLiters / 0.25).rounded())) }
    /// Total litres drunk today based on logged glasses
    var litersToday: Double { Double(glassesToday) * 0.25 }
}

// MARK: - Water Reward State
struct WaterRewardState: Codable {
    var coins: Int = 0
    var todayDrankActions: Int = 0
    var todaySkippedActions: Int = 0
    var didAwardDailyGoalBonus: Bool = false
    var totalGoalCompletions: Int = 0
    var totalDrankActions: Int = 0
    var currentStreakDays: Int = 0
    var bestStreakDays: Int = 0
    var lastGoalAchievedDate: Date?
    var ownedShopItems: [String] = []
    var lastActionDate: Date = Date.distantPast
}

private struct CloudReminderState: Codable {
    var waterSettings: WaterSettings
    var medicines: [MedicineReminder]
    var waterMotivations: [String]
    var waterRewards: WaterRewardState
    var updatedAt: Date = Date()
}

enum WaterRewardLevel: String {
    case bronze
    case silver
    case gold
    case diamond

    var minCoins: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 100
        case .gold: return 250
        case .diamond: return 500
        }
    }
}

enum WaterRewardShopItem: String, CaseIterable, Identifiable {
    case oceanTheme
    case zenAvatar
    case aiMotivationPack

    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .oceanTheme: return 60
        case .zenAvatar: return 90
        case .aiMotivationPack: return 130
        }
    }

    var icon: String {
        switch self {
        case .oceanTheme: return "paintpalette.fill"
        case .zenAvatar: return "person.crop.circle.badge.star"
        case .aiMotivationPack: return "sparkles"
        }
    }

    func title(isEnglish _: Bool) -> String {
        switch self {
        case .oceanTheme: return LanguageManager.shared.localized("water.shop.item.ocean.title")
        case .zenAvatar: return LanguageManager.shared.localized("water.shop.item.zen.title")
        case .aiMotivationPack: return LanguageManager.shared.localized("water.shop.item.ai.title")
        }
    }

    func subtitle(isEnglish _: Bool) -> String {
        switch self {
        case .oceanTheme: return LanguageManager.shared.localized("water.shop.item.ocean.subtitle")
        case .zenAvatar: return LanguageManager.shared.localized("water.shop.item.zen.subtitle")
        case .aiMotivationPack: return LanguageManager.shared.localized("water.shop.item.ai.subtitle")
        }
    }
}

// MARK: - Medicine Reminder
struct MedicineReminder: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var dose: String
    var isEnabled: Bool = true
    var times: [Date]

    static func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    }
}

// MARK: - RemindersManager
@MainActor
final class RemindersManager: ObservableObject {
    static let shared = RemindersManager()

    @Published var waterSettings: WaterSettings = WaterSettings()
    @Published var hasSavedWaterSettings: Bool = false
    @Published var medicines: [MedicineReminder] = []
    @Published var waterMotivations: [String] = []
    @Published var waterRewards: WaterRewardState = WaterRewardState()

    private let waterKey = "aura_waterSettings"
    private let medicineKey = "aura_medicineReminders"
    private let motivationsKey = "aura_waterMotivations"
    private let rewardsKey = "aura_waterRewards"
    private let db = Firestore.firestore()
    private var cloudSyncTask: Task<Void, Never>?

    private init() {
        loadAll()
        resetGlassesIfNewDay()
        restoreSchedulesIfNeeded()
        observeAuthChanges()

        if let userID = Auth.auth().currentUser?.uid {
            Task { await loadCloudState(for: userID) }
        }
    }

    // MARK: - Water

    func saveWaterSettings(_ settings: WaterSettings) {
        waterSettings = settings
        persistWater()
        hasSavedWaterSettings = true
        if settings.isEnabled {
            NotificationManager.shared.scheduleWaterReminders(
                startTime: settings.startTime,
                endTime: settings.endTime,
                intervalMinutes: settings.intervalMinutes,
                dailyGoalLiters: settings.dailyGoalLiters,
                messages: waterMotivations
            )
        } else {
            NotificationManager.shared.cancelWaterReminders()
        }
    }

    func logGlass() {
        resetRewardsIfNewDay()
        waterSettings.glassesToday = min(waterSettings.glassesToday + 1, waterSettings.dailyGoalGlasses + 5)
        waterSettings.lastLogDate = Date()
        waterRewards.lastActionDate = Date()
        persistWater()
        evaluateDailyGoalRewardIfNeeded()
    }

    func handleWaterNotificationAction(didDrink: Bool) {
        resetRewardsIfNewDay()

        if didDrink {
            waterRewards.todayDrankActions += 1
            waterRewards.totalDrankActions += 1
            addCoins(2)
            logGlass()
        } else {
            waterRewards.todaySkippedActions += 1
            waterRewards.lastActionDate = Date()
            addCoins(-1)
            persistRewards()
        }
    }

    var rewardLevel: WaterRewardLevel {
        let coins = waterRewards.coins
        if coins >= WaterRewardLevel.diamond.minCoins { return .diamond }
        if coins >= WaterRewardLevel.gold.minCoins { return .gold }
        if coins >= WaterRewardLevel.silver.minCoins { return .silver }
        return .bronze
    }

    func coinsToNextLevel() -> Int? {
        let coins = waterRewards.coins
        let ordered: [WaterRewardLevel] = [.bronze, .silver, .gold, .diamond]
        guard let currentIdx = ordered.firstIndex(of: rewardLevel), currentIdx < ordered.count - 1 else {
            return nil
        }
        let next = ordered[currentIdx + 1]
        return max(0, next.minCoins - coins)
    }

    func isShopItemOwned(_ item: WaterRewardShopItem) -> Bool {
        waterRewards.ownedShopItems.contains(item.rawValue)
    }

    func canPurchaseShopItem(_ item: WaterRewardShopItem) -> Bool {
        !isShopItemOwned(item) && waterRewards.coins >= item.cost
    }

    var hasUnlockedOceanTheme: Bool {
        isShopItemOwned(.oceanTheme)
    }

    var hasUnlockedZenAvatar: Bool {
        isShopItemOwned(.zenAvatar)
    }

    var hasUnlockedAIMotivationPack: Bool {
        isShopItemOwned(.aiMotivationPack)
    }

    @discardableResult
    func purchaseShopItem(_ item: WaterRewardShopItem) -> Bool {
        guard canPurchaseShopItem(item) else { return false }
        addCoins(-item.cost)
        waterRewards.ownedShopItems.append(item.rawValue)
        persistRewards()
        return true
    }

    func resetGlassesToday() {
        waterSettings.glassesToday = 0
        persistWater()
    }

    func restoreWaterState(settings: WaterSettings, rewards: WaterRewardState) {
        waterSettings = settings
        waterRewards = rewards
        persistWater()
        persistRewards()
    }

    func resetGlassesIfNewDay() {
        guard !Calendar.current.isDateInToday(waterSettings.lastLogDate) else { return }

        waterSettings.glassesToday = 0
        persistWater()
        resetRewardsForNewDay()
    }

    /// Fetches fresh AI water motivation messages and re-schedules notifications with them.
    func fetchAndRescheduleMotivations() async {
        let lang = LanguageManager.shared.currentLanguage == "en" ? "English" : "Türkçe"
        let desiredCount = hasUnlockedAIMotivationPack ? 20 : 12
        do {
            let msgs = try await GeminiService.shared.getWaterMotivationMessages(
                count: desiredCount,
                language: lang,
                dailyGoalLiters: waterSettings.dailyGoalLiters
            )
            waterMotivations = msgs
            persistMotivations()
            if waterSettings.isEnabled {
                NotificationManager.shared.scheduleWaterReminders(
                    startTime: waterSettings.startTime,
                    endTime: waterSettings.endTime,
                    intervalMinutes: waterSettings.intervalMinutes,
                    dailyGoalLiters: waterSettings.dailyGoalLiters,
                    messages: msgs
                )
            }
        } catch {
            print("[RemindersManager] Water motivations fetch failed: \(error)")
        }
    }

    // MARK: - Medicine

    func addMedicine(_ medicine: MedicineReminder) {
        medicines.append(medicine)
        persistMedicines()
        if medicine.isEnabled {
            NotificationManager.shared.scheduleMedicineReminders(medicine)
        }
    }

    func updateMedicine(_ medicine: MedicineReminder) {
        guard let idx = medicines.firstIndex(where: { $0.id == medicine.id }) else { return }
        medicines[idx] = medicine
        persistMedicines()
        NotificationManager.shared.cancelMedicineReminders(id: medicine.id)
        if medicine.isEnabled {
            NotificationManager.shared.scheduleMedicineReminders(medicine)
        }
    }

    func deleteMedicine(at offsets: IndexSet) {
        for idx in offsets {
            NotificationManager.shared.cancelMedicineReminders(id: medicines[idx].id)
        }
        medicines.remove(atOffsets: offsets)
        persistMedicines()
    }

    func toggleMedicine(_ medicine: MedicineReminder) {
        var updated = medicine
        updated.isEnabled.toggle()
        updateMedicine(updated)
    }

    func refreshAllReminderSchedules() {
        if waterSettings.isEnabled {
            NotificationManager.shared.scheduleWaterReminders(
                startTime: waterSettings.startTime,
                endTime: waterSettings.endTime,
                intervalMinutes: waterSettings.intervalMinutes,
                dailyGoalLiters: waterSettings.dailyGoalLiters,
                messages: waterMotivations
            )
        } else {
            NotificationManager.shared.cancelWaterReminders()
        }

        for medicine in medicines {
            NotificationManager.shared.cancelMedicineReminders(id: medicine.id)
            if medicine.isEnabled {
                NotificationManager.shared.scheduleMedicineReminders(medicine)
            }
        }
    }

    // MARK: - Persistence

    private func loadAll() {
        let hasWaterData = UserDefaults.standard.data(forKey: waterKey) != nil
        hasSavedWaterSettings = hasWaterData

        if let data = UserDefaults.standard.data(forKey: waterKey),
           let decoded = try? JSONDecoder().decode(WaterSettings.self, from: data) {
            waterSettings = decoded
        }
        if let data = UserDefaults.standard.data(forKey: medicineKey),
           let decoded = try? JSONDecoder().decode([MedicineReminder].self, from: data) {
            medicines = decoded
        }
        if let data = UserDefaults.standard.data(forKey: motivationsKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            waterMotivations = decoded
        }
        if let data = UserDefaults.standard.data(forKey: rewardsKey),
           let decoded = try? JSONDecoder().decode(WaterRewardState.self, from: data) {
            waterRewards = decoded
        }
    }

    private func persistWater() {
        guard let data = try? JSONEncoder().encode(waterSettings) else { return }
        UserDefaults.standard.set(data, forKey: waterKey)
        enqueueCloudSync()
    }

    private func persistMedicines() {
        guard let data = try? JSONEncoder().encode(medicines) else { return }
        UserDefaults.standard.set(data, forKey: medicineKey)
        enqueueCloudSync()
    }

    private func persistRewards() {
        guard let data = try? JSONEncoder().encode(waterRewards) else { return }
        UserDefaults.standard.set(data, forKey: rewardsKey)
        enqueueCloudSync()
    }

    private func persistMotivations() {
        guard let data = try? JSONEncoder().encode(waterMotivations) else { return }
        UserDefaults.standard.set(data, forKey: motivationsKey)
        enqueueCloudSync()
    }

    private func observeAuthChanges() {
        NotificationCenter.default.addObserver(
            forName: .firebaseAuthUserDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            let userID = notification.userInfo?["userID"] as? String
            guard let userID, !userID.isEmpty else { return }

            Task {
                await self.loadCloudState(for: userID)
            }
        }
    }

    private func enqueueCloudSync() {
        guard Auth.auth().currentUser?.uid != nil else { return }
        cloudSyncTask?.cancel()
        cloudSyncTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            guard !Task.isCancelled else { return }
            await self?.saveCloudState()
        }
    }

    private func cloudDocumentRef(userID: String) -> DocumentReference {
        db.collection("user_states").document(userID)
    }

    private func saveCloudState() async {
        guard let userID = Auth.auth().currentUser?.uid else { return }
        let payload = CloudReminderState(
            waterSettings: waterSettings,
            medicines: medicines,
            waterMotivations: waterMotivations,
            waterRewards: waterRewards,
            updatedAt: Date()
        )

        do {
            let encoded = try JSONEncoder().encode(payload)
            guard let jsonObject = try JSONSerialization.jsonObject(with: encoded) as? [String: Any] else {
                throw NSError(domain: "RemindersManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Cloud payload encode failed."])
            }
            try await cloudDocumentRef(userID: userID).setData(jsonObject, merge: true)
        } catch {
            print("[RemindersManager] Cloud save failed: \(error)")
        }
    }

    private func loadCloudState(for userID: String) async {
        do {
            let snapshot = try await cloudDocumentRef(userID: userID).getDocument()
            guard snapshot.exists, let data = snapshot.data() else {
                await saveCloudState()
                return
            }
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let decoded = try JSONDecoder().decode(CloudReminderState.self, from: jsonData)
            applyCloudState(decoded)
        } catch {
            print("[RemindersManager] Cloud load failed: \(error)")
        }
    }

    private func applyCloudState(_ state: CloudReminderState) {
        waterSettings = state.waterSettings
        medicines = state.medicines
        waterMotivations = state.waterMotivations
        waterRewards = state.waterRewards

        // Persist locally as cache without triggering additional network writes.
        if let waterData = try? JSONEncoder().encode(waterSettings) {
            UserDefaults.standard.set(waterData, forKey: waterKey)
        }
        if let medData = try? JSONEncoder().encode(medicines) {
            UserDefaults.standard.set(medData, forKey: medicineKey)
        }
        if let motivationData = try? JSONEncoder().encode(waterMotivations) {
            UserDefaults.standard.set(motivationData, forKey: motivationsKey)
        }
        if let rewardData = try? JSONEncoder().encode(waterRewards) {
            UserDefaults.standard.set(rewardData, forKey: rewardsKey)
        }

        restoreSchedulesIfNeeded()
    }

    private func resetRewardsIfNewDay() {
        guard !Calendar.current.isDateInToday(waterRewards.lastActionDate) else { return }
        resetRewardsForNewDay()
    }

    private func resetRewardsForNewDay() {
        waterRewards.todayDrankActions = 0
        waterRewards.todaySkippedActions = 0
        waterRewards.didAwardDailyGoalBonus = false
        waterRewards.lastActionDate = Date()
        persistRewards()
    }

    private func evaluateDailyGoalRewardIfNeeded() {
        if waterSettings.glassesToday >= waterSettings.dailyGoalGlasses,
           !waterRewards.didAwardDailyGoalBonus {
            waterRewards.didAwardDailyGoalBonus = true
            waterRewards.totalGoalCompletions += 1
            addCoins(10)
            updateGoalStreak(date: Date())

            // Weekly streak reward: +20 coin every 7 consecutive days.
            if waterRewards.currentStreakDays > 0 && waterRewards.currentStreakDays % 7 == 0 {
                addCoins(20)
            }
        }

        persistRewards()
    }

    private func updateGoalStreak(date: Date) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)

        if let last = waterRewards.lastGoalAchievedDate {
            if calendar.isDate(last, inSameDayAs: today) {
                return
            }

            if let yesterday = calendar.date(byAdding: .day, value: -1, to: today),
               calendar.isDate(last, inSameDayAs: yesterday) {
                waterRewards.currentStreakDays += 1
            } else {
                waterRewards.currentStreakDays = 1
            }
        } else {
            waterRewards.currentStreakDays = 1
        }

        waterRewards.lastGoalAchievedDate = today
        waterRewards.bestStreakDays = max(waterRewards.bestStreakDays, waterRewards.currentStreakDays)
    }

    private func addCoins(_ delta: Int) {
        waterRewards.coins = max(0, waterRewards.coins + delta)
    }

    private func restoreSchedulesIfNeeded() {
        if hasSavedWaterSettings && waterSettings.isEnabled {
            NotificationManager.shared.scheduleWaterReminders(
                startTime: waterSettings.startTime,
                endTime: waterSettings.endTime,
                intervalMinutes: waterSettings.intervalMinutes,
                dailyGoalLiters: waterSettings.dailyGoalLiters,
                messages: waterMotivations
            )
        }

        for medicine in medicines where medicine.isEnabled {
            NotificationManager.shared.scheduleMedicineReminders(medicine)
        }
    }
}
