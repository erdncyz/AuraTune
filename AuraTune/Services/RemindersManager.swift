import Foundation
import SwiftUI
import Combine

// MARK: - Water Settings
struct WaterSettings: Codable {
    var isEnabled: Bool = true
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
    @Published var medicines: [MedicineReminder] = []
    @Published var waterMotivations: [String] = []

    private let waterKey = "aura_waterSettings"
    private let medicineKey = "aura_medicineReminders"
    private let motivationsKey = "aura_waterMotivations"

    private init() {
        loadAll()
        resetGlassesIfNewDay()
        restoreSchedulesIfNeeded()
    }

    // MARK: - Water

    func saveWaterSettings(_ settings: WaterSettings) {
        waterSettings = settings
        persistWater()
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
        waterSettings.glassesToday = min(waterSettings.glassesToday + 1, waterSettings.dailyGoalGlasses + 5)
        waterSettings.lastLogDate = Date()
        persistWater()
    }

    func resetGlassesToday() {
        waterSettings.glassesToday = 0
        persistWater()
    }

    func resetGlassesIfNewDay() {
        guard !Calendar.current.isDateInToday(waterSettings.lastLogDate) else { return }

        waterSettings.glassesToday = 0
        persistWater()
    }

    /// Fetches fresh AI water motivation messages and re-schedules notifications with them.
    func fetchAndRescheduleMotivations() async {
        let lang = LanguageManager.shared.currentLanguage == "en" ? "English" : "Türkçe"
        do {
            let msgs = try await GeminiService.shared.getWaterMotivationMessages(
                count: 12,
                language: lang,
                dailyGoalLiters: waterSettings.dailyGoalLiters
            )
            waterMotivations = msgs
            if let data = try? JSONEncoder().encode(msgs) {
                UserDefaults.standard.set(data, forKey: motivationsKey)
            }
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

    // MARK: - Persistence

    private func loadAll() {
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
    }

    private func persistWater() {
        guard let data = try? JSONEncoder().encode(waterSettings) else { return }
        UserDefaults.standard.set(data, forKey: waterKey)
    }

    private func persistMedicines() {
        guard let data = try? JSONEncoder().encode(medicines) else { return }
        UserDefaults.standard.set(data, forKey: medicineKey)
    }

    private func restoreSchedulesIfNeeded() {
        if waterSettings.isEnabled {
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
