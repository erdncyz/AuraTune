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
    var spendableDrops: Int = 0
    var lifetimeDropsEarned: Int = 0
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

    enum CodingKeys: String, CodingKey {
        case spendableDrops = "coins"
        case lifetimeDropsEarned
        case todayDrankActions
        case todaySkippedActions
        case didAwardDailyGoalBonus
        case totalGoalCompletions
        case totalDrankActions
        case currentStreakDays
        case bestStreakDays
        case lastGoalAchievedDate
        case ownedShopItems
        case lastActionDate
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spendableDrops = try container.decodeIfPresent(Int.self, forKey: .spendableDrops) ?? 0
        todayDrankActions = try container.decodeIfPresent(Int.self, forKey: .todayDrankActions) ?? 0
        todaySkippedActions = try container.decodeIfPresent(Int.self, forKey: .todaySkippedActions) ?? 0
        didAwardDailyGoalBonus = try container.decodeIfPresent(Bool.self, forKey: .didAwardDailyGoalBonus) ?? false
        totalGoalCompletions = try container.decodeIfPresent(Int.self, forKey: .totalGoalCompletions) ?? 0
        totalDrankActions = try container.decodeIfPresent(Int.self, forKey: .totalDrankActions) ?? 0
        currentStreakDays = try container.decodeIfPresent(Int.self, forKey: .currentStreakDays) ?? 0
        bestStreakDays = try container.decodeIfPresent(Int.self, forKey: .bestStreakDays) ?? 0
        lastGoalAchievedDate = try container.decodeIfPresent(Date.self, forKey: .lastGoalAchievedDate)
        ownedShopItems = try container.decodeIfPresent([String].self, forKey: .ownedShopItems) ?? []
        lastActionDate = try container.decodeIfPresent(Date.self, forKey: .lastActionDate) ?? .distantPast
        lifetimeDropsEarned = try container.decodeIfPresent(Int.self, forKey: .lifetimeDropsEarned)
            ?? max(spendableDrops, totalDrankActions + (totalGoalCompletions * 5))
    }
}

struct MedicineRewardState: Codable {
    var todayTookActions: Int = 0
    var todaySkippedActions: Int = 0
    var totalTookActions: Int = 0
    var totalSkippedActions: Int = 0
    var lastActionDate: Date = Date.distantPast
}

private struct CloudReminderState: Codable {
    var waterSettings: WaterSettings
    var medicines: [MedicineReminder]
    var waterMotivations: [String]
    var waterRewards: WaterRewardState
    var medicineRewards: MedicineRewardState
    var updatedAt: Date = Date()

    enum CodingKeys: String, CodingKey {
        case waterSettings
        case medicines
        case waterMotivations
        case waterRewards
        case medicineRewards
        case updatedAt
    }

    init(
        waterSettings: WaterSettings,
        medicines: [MedicineReminder],
        waterMotivations: [String],
        waterRewards: WaterRewardState,
        medicineRewards: MedicineRewardState,
        updatedAt: Date = Date()
    ) {
        self.waterSettings = waterSettings
        self.medicines = medicines
        self.waterMotivations = waterMotivations
        self.waterRewards = waterRewards
        self.medicineRewards = medicineRewards
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        waterSettings = try container.decode(WaterSettings.self, forKey: .waterSettings)
        medicines = try container.decode([MedicineReminder].self, forKey: .medicines)
        waterMotivations = try container.decodeIfPresent([String].self, forKey: .waterMotivations) ?? []
        waterRewards = try container.decodeIfPresent(WaterRewardState.self, forKey: .waterRewards) ?? WaterRewardState()
        medicineRewards = try container.decodeIfPresent(MedicineRewardState.self, forKey: .medicineRewards) ?? MedicineRewardState()
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
    }
}

enum WaterRewardLevel: String {
    case bronze
    case silver
    case gold
    case diamond

    var minLifetimeDrops: Int {
        switch self {
        case .bronze: return 0
        case .silver: return 50
        case .gold: return 150
        case .diamond: return 350
        }
    }
}

enum WaterRewardShopItem: String, CaseIterable, Identifiable {
    case smartSnooze = "oceanTheme"
    case progressCoach = "zenAvatar"
    case flexibleStreak = "aiMotivationPack"

    var id: String { rawValue }

    var cost: Int {
        switch self {
        case .smartSnooze: return 30
        case .progressCoach: return 55
        case .flexibleStreak: return 90
        }
    }

    var icon: String {
        switch self {
        case .smartSnooze: return "clock.arrow.circlepath"
        case .progressCoach: return "chart.line.uptrend.xyaxis"
        case .flexibleStreak: return "shield.lefthalf.filled"
        }
    }

    func title(isEnglish _: Bool) -> String {
        switch self {
        case .smartSnooze: return LanguageManager.shared.localized("water.shop.item.snooze.title")
        case .progressCoach: return LanguageManager.shared.localized("water.shop.item.progress.title")
        case .flexibleStreak: return LanguageManager.shared.localized("water.shop.item.streak.title")
        }
    }

    func subtitle(isEnglish _: Bool) -> String {
        switch self {
        case .smartSnooze: return LanguageManager.shared.localized("water.shop.item.snooze.subtitle")
        case .progressCoach: return LanguageManager.shared.localized("water.shop.item.progress.subtitle")
        case .flexibleStreak: return LanguageManager.shared.localized("water.shop.item.streak.subtitle")
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
    @Published var medicineRewards: MedicineRewardState = MedicineRewardState()

    private let waterKey = "aura_waterSettings"
    private let medicineKey = "aura_medicineReminders"
    private let motivationsKey = "aura_waterMotivations"
    private let rewardsKey = "aura_waterRewards"
    private let medicineRewardsKey = "aura_medicineRewards"
    private let motivationRefreshSuccessKey = "aura_waterMotivationsLastSuccess"
    private let motivationRefreshAttemptKey = "aura_waterMotivationsLastAttempt"
    private let motivationPromptVersionKey = "aura_waterMotivationsPromptVersion"
    private let currentMotivationPromptVersion = 2
    private let db = Firestore.firestore()
    private var cloudSyncTask: Task<Void, Never>?
    private var motivationRefreshTask: Task<Void, Never>?

    private init() {
        loadAll()
        syncWaterRewardFeatures()
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
            scheduleCurrentWaterReminders()
        } else {
            NotificationManager.shared.cancelWaterReminders()
        }
    }

    func logGlass() {
        resetRewardsIfNewDay()
        let maximumGlasses = waterSettings.dailyGoalGlasses + 5
        guard waterSettings.glassesToday < maximumGlasses else { return }

        let earnsDrop = waterSettings.glassesToday < waterSettings.dailyGoalGlasses
        waterSettings.glassesToday += 1
        waterSettings.lastLogDate = Date()
        waterRewards.todayDrankActions += 1
        waterRewards.totalDrankActions += 1
        waterRewards.lastActionDate = Date()
        if earnsDrop {
            earnDrops(1)
        }
        persistWater()
        evaluateDailyGoalRewardIfNeeded()
        if waterSettings.isEnabled, hasUnlockedProgressCoach {
            scheduleCurrentWaterReminders()
        }
    }

    func handleWaterNotificationAction(didDrink: Bool) {
        resetRewardsIfNewDay()

        if didDrink {
            logGlass()
        } else {
            waterRewards.todaySkippedActions += 1
            waterRewards.lastActionDate = Date()
            persistRewards()
        }
    }

    func handleMedicineNotificationAction(tookMedicine: Bool) {
        resetMedicineRewardsIfNewDay()

        if tookMedicine {
            medicineRewards.todayTookActions += 1
            medicineRewards.totalTookActions += 1
        } else {
            medicineRewards.todaySkippedActions += 1
            medicineRewards.totalSkippedActions += 1
        }

        medicineRewards.lastActionDate = Date()
        persistMedicineRewards()
    }

    var rewardLevel: WaterRewardLevel {
        let lifetimeDrops = waterRewards.lifetimeDropsEarned
        if lifetimeDrops >= WaterRewardLevel.diamond.minLifetimeDrops { return .diamond }
        if lifetimeDrops >= WaterRewardLevel.gold.minLifetimeDrops { return .gold }
        if lifetimeDrops >= WaterRewardLevel.silver.minLifetimeDrops { return .silver }
        return .bronze
    }

    func dropsToNextLevel() -> Int? {
        let lifetimeDrops = waterRewards.lifetimeDropsEarned
        let ordered: [WaterRewardLevel] = [.bronze, .silver, .gold, .diamond]
        guard let currentIdx = ordered.firstIndex(of: rewardLevel), currentIdx < ordered.count - 1 else {
            return nil
        }
        let next = ordered[currentIdx + 1]
        return max(0, next.minLifetimeDrops - lifetimeDrops)
    }

    func isShopItemOwned(_ item: WaterRewardShopItem) -> Bool {
        waterRewards.ownedShopItems.contains(item.rawValue)
    }

    func canPurchaseShopItem(_ item: WaterRewardShopItem) -> Bool {
        !isShopItemOwned(item) && waterRewards.spendableDrops >= item.cost
    }

    var hasUnlockedSmartSnooze: Bool {
        isShopItemOwned(.smartSnooze)
    }

    var hasUnlockedProgressCoach: Bool {
        isShopItemOwned(.progressCoach)
    }

    var hasUnlockedFlexibleStreak: Bool {
        isShopItemOwned(.flexibleStreak)
    }

    @discardableResult
    func purchaseShopItem(_ item: WaterRewardShopItem) -> Bool {
        guard canPurchaseShopItem(item) else { return false }
        spendDrops(item.cost)
        waterRewards.ownedShopItems.append(item.rawValue)
        persistRewards()
        syncWaterRewardFeatures()
        if waterSettings.isEnabled {
            scheduleCurrentWaterReminders()
        }
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
        if let motivationRefreshTask {
            await motivationRefreshTask.value
            return
        }

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.performWaterMotivationRefresh()
        }
        motivationRefreshTask = task
        await task.value
        motivationRefreshTask = nil
    }

    private func performWaterMotivationRefresh() async {
        UserDefaults.standard.set(Date(), forKey: motivationRefreshAttemptKey)
        let lang = LanguageManager.shared.currentLanguage == "en" ? "English" : "Türkçe"
        let desiredCount = 18
        do {
            let msgs = try await GeminiService.shared.getWaterMotivationMessages(
                count: desiredCount,
                language: lang,
                dailyGoalLiters: waterSettings.dailyGoalLiters
            )
            waterMotivations = msgs
            UserDefaults.standard.set(Date(), forKey: motivationRefreshSuccessKey)
            UserDefaults.standard.set(
                currentMotivationPromptVersion,
                forKey: motivationPromptVersionKey
            )
            persistMotivations()
            if waterSettings.isEnabled {
                scheduleCurrentWaterReminders()
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
            scheduleCurrentWaterReminders()
            refreshWaterMotivationsIfNeeded()
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
        if let data = UserDefaults.standard.data(forKey: medicineRewardsKey),
           let decoded = try? JSONDecoder().decode(MedicineRewardState.self, from: data) {
            medicineRewards = decoded
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

    private func persistMedicineRewards() {
        guard let data = try? JSONEncoder().encode(medicineRewards) else { return }
        UserDefaults.standard.set(data, forKey: medicineRewardsKey)
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
            medicineRewards: medicineRewards,
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
        medicineRewards = state.medicineRewards
        syncWaterRewardFeatures()

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
        if let medicineRewardData = try? JSONEncoder().encode(medicineRewards) {
            UserDefaults.standard.set(medicineRewardData, forKey: medicineRewardsKey)
        }

        restoreSchedulesIfNeeded()
    }

    private func resetRewardsIfNewDay() {
        guard !Calendar.current.isDateInToday(waterRewards.lastActionDate) else { return }
        resetRewardsForNewDay()
    }

    private func resetMedicineRewardsIfNewDay() {
        guard !Calendar.current.isDateInToday(medicineRewards.lastActionDate) else { return }
        medicineRewards.todayTookActions = 0
        medicineRewards.todaySkippedActions = 0
        medicineRewards.lastActionDate = Date()
        persistMedicineRewards()
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
            earnDrops(5)
            updateGoalStreak(date: Date())

            // Reward a consistent week without making missed reminders punitive.
            if waterRewards.currentStreakDays > 0 && waterRewards.currentStreakDays % 7 == 0 {
                earnDrops(15)
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
            } else if hasUnlockedFlexibleStreak,
                      let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today),
                      calendar.isDate(last, inSameDayAs: twoDaysAgo) {
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

    private func earnDrops(_ amount: Int) {
        guard amount > 0 else { return }
        waterRewards.spendableDrops += amount
        waterRewards.lifetimeDropsEarned += amount
    }

    private func spendDrops(_ amount: Int) {
        guard amount > 0 else { return }
        waterRewards.spendableDrops = max(0, waterRewards.spendableDrops - amount)
    }

    private func syncWaterRewardFeatures() {
        NotificationManager.shared.configureWaterRewardFeatures(
            snoozeUnlocked: hasUnlockedSmartSnooze
        )
    }

    private func scheduleCurrentWaterReminders() {
        NotificationManager.shared.scheduleWaterReminders(
            startTime: waterSettings.startTime,
            endTime: waterSettings.endTime,
            intervalMinutes: waterSettings.intervalMinutes,
            dailyGoalLiters: waterSettings.dailyGoalLiters,
            messages: waterMotivations,
            glassesToday: waterSettings.glassesToday,
            showsGoalProgress: hasUnlockedProgressCoach
        )
    }

    private func refreshWaterMotivationsIfNeeded() {
        guard motivationRefreshTask == nil else { return }

        let defaults = UserDefaults.standard
        let now = Date()
        let lastSuccess = defaults.object(forKey: motivationRefreshSuccessKey) as? Date
        let lastAttempt = defaults.object(forKey: motivationRefreshAttemptKey) as? Date
        let needsMessages = waterMotivations.count < 6
        let needsQualityUpgrade = defaults.integer(forKey: motivationPromptVersionKey)
            < currentMotivationPromptVersion
        let isWeeklyRefreshDue = lastSuccess.map {
            now.timeIntervalSince($0) >= 7 * 24 * 60 * 60
        } ?? true
        let canRetry = lastAttempt.map {
            now.timeIntervalSince($0) >= 6 * 60 * 60
        } ?? true

        guard canRetry, needsMessages || needsQualityUpgrade || isWeeklyRefreshDue else { return }
        Task { await fetchAndRescheduleMotivations() }
    }

    private func restoreSchedulesIfNeeded() {
        if hasSavedWaterSettings && waterSettings.isEnabled {
            scheduleCurrentWaterReminders()
            refreshWaterMotivationsIfNeeded()
        }

        for medicine in medicines where medicine.isEnabled {
            NotificationManager.shared.scheduleMedicineReminders(medicine)
        }
    }
}
