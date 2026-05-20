import SwiftUI

// MARK: - RemindersView (Root)
struct RemindersView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var remindersManager: RemindersManager
    @State private var selectedTab: ReminderTab = .water

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    enum ReminderTab { case water, medicine }

    private var heroGradientColors: [Color] {
        selectedTab == .water
            ? [Color(hex: "1A6BB5"), Color(hex: "4FC3F7")]
            : [Color(hex: "6A1B9A"), Color(hex: "AB47BC")]
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface.ignoresSafeArea()

                // Hero gradient
                LinearGradient(
                    colors: heroGradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 280)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Hero
                        remindersHero
                        // Content
                        if selectedTab == .water {
                            WaterReminderSection(isEnglish: isEnglish)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .leading).combined(with: .opacity),
                                    removal: .move(edge: .trailing).combined(with: .opacity)
                                ))
                        } else {
                            MedicineReminderSection(isEnglish: isEnglish)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)
                                ))
                        }
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Hero
    private var remindersHero: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEnglish ? "Reminders" : "Hatırlatıcı")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: selectedTab == .water ? "drop.fill" : "pills.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.white)
                }
            }

            segmentPicker
                .padding(.horizontal, 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 24)
        .padding(.bottom, 18)
    }

    // MARK: - Segment Picker
    private var segmentPicker: some View {
        HStack(spacing: 0) {
            tabButton(
                title: isEnglish ? "💧 Water" : "💧 Su",
                tab: .water
            )
            tabButton(
                title: isEnglish ? "💊 Medicine" : "💊 İlaç",
                tab: .medicine
            )
        }
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
    }

    private func tabButton(title: String, tab: ReminderTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                selectedTab = tab
            }
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selectedTab == tab ? .white : Color.auraOnSurface.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selectedTab == tab
                        ? (tab == .water ? Color(hex: "0288D1") : Color(hex: "7B1FA2"))
                        : Color.clear
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Water Reminder Section
struct WaterReminderSection: View {
    let isEnglish: Bool
    @EnvironmentObject var remindersManager: RemindersManager

    @State private var draftSettings: WaterSettings = WaterSettings()
    @State private var showSaved: Bool = false
    @State private var isLoadingMotivations: Bool = false

    let intervalOptions = [15, 30, 45, 60, 90, 120, 180, 240]

    func intervalLabel(_ min: Int) -> String {
        switch min {
        case 60: return isEnglish ? "Every 1 hr" : "Her 1 saat"
        case 90: return isEnglish ? "Every 1.5 hr" : "Her 1,5 saat"
        case 120: return isEnglish ? "Every 2 hr" : "Her 2 saat"
        case 180: return isEnglish ? "Every 3 hr" : "Her 3 saat"
        case 240: return isEnglish ? "Every 4 hr" : "Her 4 saat"
        default:
            return isEnglish ? "Every \(min) min" : "Her \(min) dk"
        }
    }

    var progressFraction: Double {
        guard draftSettings.dailyGoalLiters > 0 else { return 0 }
        return min(remindersManager.waterSettings.litersToday / draftSettings.dailyGoalLiters, 1.0)
    }

    private var hasUnsavedChanges: Bool {
        let saved = remindersManager.waterSettings
        return draftSettings.isEnabled != saved.isEnabled
            || draftSettings.intervalMinutes != saved.intervalMinutes
            || abs(draftSettings.dailyGoalLiters - saved.dailyGoalLiters) > 0.001
            || minuteOfDay(draftSettings.startTime) != minuteOfDay(saved.startTime)
            || minuteOfDay(draftSettings.endTime) != minuteOfDay(saved.endTime)
    }

    private var saveButtonTitle: String {
        if isLoadingMotivations {
            return isEnglish ? "Saving..." : "Kaydediliyor..."
        }
        if showSaved {
            return isEnglish ? "Saved!" : "Kaydedildi!"
        }
        if hasUnsavedChanges {
            return isEnglish ? "Save Settings" : "Kaydet"
        }
        return isEnglish ? "Up to Date" : "Güncel"
    }

    private var saveButtonIcon: String {
        if isLoadingMotivations {
            return "hourglass"
        }
        if showSaved || !hasUnsavedChanges {
            return "checkmark.circle.fill"
        }
        return "square.and.arrow.down.fill"
    }

    private func minuteOfDay(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Settings Card
            waterSettingsCard
            // Save
            saveButton
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .onAppear { draftSettings = remindersManager.waterSettings }
    }

    // MARK: Progress Card
    private var waterProgressCard: some View {
        M3Card {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isEnglish ? "Today's Progress" : "Bugünkü İlerleme")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.auraOnSurface)
                    }
                    Spacer()
                    // Circular Progress
                    ZStack {
                        Circle()
                            .stroke(Color(hex: "4FC3F7").opacity(0.2), lineWidth: 8)
                            .frame(width: 72, height: 72)
                        Circle()
                            .trim(from: 0, to: progressFraction)
                            .stroke(
                                LinearGradient(
                                    colors: [Color(hex: "0288D1"), Color(hex: "4FC3F7")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 8, lineCap: .round)
                            )
                            .frame(width: 72, height: 72)
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progressFraction)
                        VStack(spacing: 1) {
                            Text(String(format: "%.2g", remindersManager.waterSettings.litersToday))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(Color(hex: "0288D1"))
                            Text("L")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(Color(hex: "4FC3F7"))
                        }
                    }
                }

                // Log button
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        remindersManager.logGlass()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(isEnglish ? "Log a Glass" : "Bardak İçtim")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "0288D1"), Color(hex: "4FC3F7")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(remindersManager.waterSettings.glassesToday >= draftSettings.dailyGoalGlasses + 5)

                if remindersManager.waterSettings.litersToday >= draftSettings.dailyGoalLiters {
                    Text(isEnglish ? "🎉 Daily goal achieved!" : "🎉 Günlük hedefe ulaştın!")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(hex: "0288D1"))
                }
            }
        }
    }

    // MARK: Settings Card
    private var waterSettingsCard: some View {
        M3Card {
            VStack(spacing: 0) {
                // Enable Toggle
                HStack {
                    Image(systemName: "bell.badge.fill")
                        .foregroundColor(Color(hex: "0288D1"))
                        .font(.system(size: 18))
                    Text(isEnglish ? "Water Reminders" : "Su Hatırlatıcısı")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.auraOnSurface)
                    Spacer()
                    Toggle("", isOn: $draftSettings.isEnabled)
                        .tint(Color(hex: "0288D1"))
                }
                .padding(.bottom, 16)

                if draftSettings.isEnabled {
                    Divider().padding(.bottom, 16)

                    // Interval
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isEnglish ? "Reminder Interval" : "Hatırlatma Aralığı")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.auraOnSurface.opacity(0.6))

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(intervalOptions, id: \.self) { min in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        draftSettings.intervalMinutes = min
                                    }
                                } label: {
                                    Text(intervalLabel(min))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(draftSettings.intervalMinutes == min ? .white : .auraOnSurface.opacity(0.7))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(
                                            draftSettings.intervalMinutes == min
                                                ? Color(hex: "0288D1")
                                                : Color.auraOnSurface.opacity(0.06)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    Divider().padding(.bottom, 16)

                    // Active Hours
                    VStack(alignment: .leading, spacing: 10) {
                        Text(isEnglish ? "Active Hours" : "Aktif Saatler")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.auraOnSurface.opacity(0.6))

                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isEnglish ? "Start" : "Başlangıç")
                                    .font(.caption)
                                    .foregroundColor(.auraOnSurface.opacity(0.5))
                                DatePicker("", selection: $draftSettings.startTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(Color(hex: "0288D1"))
                            }
                            Image(systemName: "arrow.right")
                                .foregroundColor(.auraOnSurface.opacity(0.3))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(isEnglish ? "End" : "Bitiş")
                                    .font(.caption)
                                    .foregroundColor(.auraOnSurface.opacity(0.5))
                                DatePicker("", selection: $draftSettings.endTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .tint(Color(hex: "0288D1"))
                            }
                            Spacer()
                        }
                    }
                    .padding(.bottom, 16)

                    Divider().padding(.bottom, 16)

                    // Daily Goal
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(isEnglish ? "Daily Goal" : "Günlük Hedef")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.auraOnSurface.opacity(0.6))
                            Spacer()
                            Text(String(format: isEnglish ? "%.1f litres" : "%.1f litre", draftSettings.dailyGoalLiters))
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "0288D1"))
                        }
                        Slider(value: $draftSettings.dailyGoalLiters, in: 1.0...4.5, step: 0.25)
                            .tint(Color(hex: "0288D1"))
                        HStack {
                            Text("1L")
                                .font(.caption2)
                                .foregroundColor(.auraOnSurface.opacity(0.4))
                            Spacer()
                            Text("4.5L")
                                .font(.caption2)
                                .foregroundColor(.auraOnSurface.opacity(0.4))
                        }
                    }

                    Divider().padding(.vertical, 8)

                    // AI Motivations status
                    HStack(spacing: 8) {
                        if isLoadingMotivations {
                            ProgressView()
                                .scaleEffect(0.75)
                                .tint(Color(hex: "0288D1"))
                            Text(isEnglish ? "Fetching AI motivation messages..." : "AI motivasyon mesajları alınıyor...")
                                .font(.system(size: 12))
                                .foregroundColor(.auraOnSurface.opacity(0.55))
                        } else if !remindersManager.waterMotivations.isEmpty {
                            Image(systemName: "sparkles")
                                .foregroundColor(Color(hex: "0288D1"))
                                .font(.system(size: 13))
                            Text(isEnglish
                                 ? "\(remindersManager.waterMotivations.count) AI messages ready ✓"
                                 : "\(remindersManager.waterMotivations.count) AI mesajı hazır ✓")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Color(hex: "0288D1"))
                        } else {
                            Image(systemName: "sparkles")
                                .foregroundColor(.auraOnSurface.opacity(0.35))
                                .font(.system(size: 13))
                            Text(isEnglish ? "AI messages will be generated on save" : "Kaydet'te AI mesajları oluşturulacak")
                                .font(.system(size: 12))
                                .foregroundColor(.auraOnSurface.opacity(0.5))
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    private var saveButton: some View {
        Button {
            withAnimation {
                remindersManager.saveWaterSettings(draftSettings)
                showSaved = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation { showSaved = false }
            }
            if draftSettings.isEnabled {
                isLoadingMotivations = true
                Task {
                    let manager = remindersManager
                    await manager.fetchAndRescheduleMotivations()
                    isLoadingMotivations = false
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: saveButtonIcon)
                Text(saveButtonTitle)
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                Group {
                    if showSaved {
                        Color.green
                    } else if !hasUnsavedChanges {
                        Color.auraOnSurface.opacity(0.3)
                    } else {
                        LinearGradient(
                            colors: [Color(hex: "0288D1"), Color(hex: "4FC3F7")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: showSaved)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: hasUnsavedChanges)
        }
        .buttonStyle(.plain)
        .disabled(!hasUnsavedChanges || isLoadingMotivations)
    }
}

// MARK: - Medicine Reminder Section
struct MedicineReminderSection: View {
    let isEnglish: Bool
    @EnvironmentObject var remindersManager: RemindersManager
    @State private var showAddSheet: Bool = false
    @State private var editingMedicine: MedicineReminder? = nil

    var body: some View {
        VStack(spacing: 16) {
            // List
            if remindersManager.medicines.isEmpty {
                emptyState
            } else {
                ForEach(remindersManager.medicines) { medicine in
                    medicineRow(medicine)
                }
                .padding(.top, 4)
            }
            // Add Button
            Button {
                showAddSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text(isEnglish ? "Add Medicine" : "İlaç Ekle")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "6A1B9A"), Color(hex: "AB47BC")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .sheet(isPresented: $showAddSheet) {
            MedicineEditSheet(isEnglish: isEnglish, medicine: nil) { medicine in
                remindersManager.addMedicine(medicine)
            }
        }
        .sheet(item: $editingMedicine) { medicine in
            MedicineEditSheet(isEnglish: isEnglish, medicine: medicine) { updated in
                remindersManager.updateMedicine(updated)
            }
        }
    }

    private var emptyState: some View {
        M3Card {
            VStack(spacing: 16) {
                Image(systemName: "pills")
                    .font(.system(size: 44))
                    .foregroundColor(Color(hex: "AB47BC").opacity(0.4))
                Text(isEnglish
                     ? "No medicine reminders yet"
                     : "Henüz ilaç hatırlatıcısı yok")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.auraOnSurface.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        }
    }

    private func medicineRow(_ medicine: MedicineReminder) -> some View {
        M3Card {
            HStack(spacing: 14) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(medicine.isEnabled
                              ? Color(hex: "AB47BC").opacity(0.15)
                              : Color.gray.opacity(0.1))
                        .frame(width: 46, height: 46)
                    Image(systemName: "pills.fill")
                        .font(.system(size: 20))
                        .foregroundColor(medicine.isEnabled ? Color(hex: "7B1FA2") : .gray)
                }

                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(medicine.name)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.auraOnSurface)
                    Text(medicine.dose)
                        .font(.system(size: 12))
                        .foregroundColor(.auraOnSurface.opacity(0.55))
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "AB47BC").opacity(0.7))
                        Text(medicine.times.map { timeString($0) }.joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(.auraOnSurface.opacity(0.55))
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    // Toggle
                    Toggle("", isOn: Binding(
                        get: { medicine.isEnabled },
                        set: { _ in remindersManager.toggleMedicine(medicine) }
                    ))
                    .tint(Color(hex: "7B1FA2"))
                    .scaleEffect(0.85)

                    // Edit
                    Button {
                        editingMedicine = medicine
                    } label: {
                        Image(systemName: "pencil.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(hex: "AB47BC").opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                if let idx = remindersManager.medicines.firstIndex(where: { $0.id == medicine.id }) {
                    remindersManager.deleteMedicine(at: IndexSet(integer: idx))
                }
            } label: {
                Label(isEnglish ? "Delete" : "Sil", systemImage: "trash")
            }
        }
    }

    private func timeString(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }
}

// MARK: - Medicine Edit Sheet
struct MedicineEditSheet: View {
    let isEnglish: Bool
    let medicine: MedicineReminder?
    let onSave: (MedicineReminder) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var name: String = ""
    @State private var dose: String = ""
    @State private var times: [Date] = [MedicineReminder.defaultTime()]

    var isEditing: Bool { medicine != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Name
                    VStack(alignment: .leading, spacing: 8) {
                        label(isEnglish ? "Medicine Name" : "İlaç Adı")
                        TextField(isEnglish ? "e.g. Vitamin D" : "örn. D Vitamini", text: $name)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color.auraOnSurface.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Dose
                    VStack(alignment: .leading, spacing: 8) {
                        label(isEnglish ? "Dose" : "Doz")
                        TextField(isEnglish ? "e.g. 1 tablet" : "örn. 1 tablet", text: $dose)
                            .textFieldStyle(.plain)
                            .padding(14)
                            .background(Color.auraOnSurface.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    // Times
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            label(isEnglish ? "Reminder Times" : "Hatırlatma Saatleri")
                            Spacer()
                            Button {
                                withAnimation { times.append(MedicineReminder.defaultTime()) }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(Color(hex: "7B1FA2"))
                                    .font(.system(size: 22))
                            }
                            .buttonStyle(.plain)
                        }

                        ForEach(Array(times.enumerated()), id: \.offset) { idx, _ in
                            timeRow(idx: idx)
                        }
                    }

                    Spacer(minLength: 20)

                    // Save
                    Button {
                        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        var result = medicine ?? MedicineReminder(name: name, dose: dose, times: times)
                        result.name = name
                        result.dose = dose.isEmpty ? (isEnglish ? "1 dose" : "1 doz") : dose
                        result.times = times
                        onSave(result)
                        dismiss()
                    } label: {
                        saveLabel
                    }
                    .buttonStyle(.plain)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(20)
            }
            .background(Color.auraSurface.ignoresSafeArea())
            .navigationTitle(isEditing
                             ? (isEnglish ? "Edit Medicine" : "İlaç Düzenle")
                             : (isEnglish ? "Add Medicine" : "İlaç Ekle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEnglish ? "Cancel" : "İptal") { dismiss() }
                        .foregroundColor(Color(hex: "7B1FA2"))
                }
            }
        }
        .onAppear {
            if let m = medicine {
                name = m.name
                dose = m.dose
                times = m.times.isEmpty ? [MedicineReminder.defaultTime()] : m.times
            }
        }
    }

    private var timeRowBackground: Color {
        Color(red: 0.12, green: 0.11, blue: 0.29, opacity: 0.05)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.auraOnSurface.opacity(0.55))
    }

    @ViewBuilder
    private func timeRow(idx: Int) -> some View {
        HStack {
            DatePicker("", selection: $times[idx], displayedComponents: .hourAndMinute)
                .labelsHidden()
                .tint(Color(hex: "7B1FA2"))
            Spacer()
            if times.count > 1 {
                Button {
                    let i = idx
                    withAnimation { times.remove(at: i) }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundColor(Color.red.opacity(0.7))
                        .font(.system(size: 22))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(timeRowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var saveLabel: some View {
        let isEmpty = name.trimmingCharacters(in: .whitespaces).isEmpty
        let bgColor = Color(red: 0.5, green: 0.5, blue: 0.5, opacity: 0.4)
        return Text(isEnglish ? "Save" : "Kaydet")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                ZStack {
                    if !isEmpty {
                        LinearGradient(
                            colors: [Color(hex: "6A1B9A"), Color(hex: "AB47BC")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    } else {
                        bgColor
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
