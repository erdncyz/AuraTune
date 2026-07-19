import SwiftUI
import FirebaseAuth
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject var firebaseManager: FirebaseManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var remindersManager: RemindersManager
    @EnvironmentObject var favoritesManager: FavoritesManager
    @EnvironmentObject var historyManager: HistoryManager
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var notificationManager = NotificationManager.shared
    @FocusState private var isNameFocused: Bool
    @State private var showSavedToast = false
    @State private var showAbout = false
    @State private var authActionError: String?
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var notificationTestMessage: String?

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }
    private let genreColumns = [GridItem(.adaptive(minimum: 92), spacing: 8)]

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: isEnglish ? "Profile & preferences" : "Profil ve tercihler",
                    title: viewModel.userName.isEmpty ? "AuraTune" : viewModel.userName,
                    subtitle: firebaseManager.currentUser?.email,
                    icon: "person.fill",
                    accent: .auraPrimary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AuraMetrics.sectionSpacing) {
                        profileSnapshot
                        preferenceSection
                        personalSection
                        dailyMusicNotificationSection
                        genreSection
                        platformSection
                        aboutRow
                        accountSection

                        if let authActionError {
                            errorPanel(authActionError)
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 22)
                    .padding(.bottom, 28)
                    .auraContentColumn()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if viewModel.hasChanges {
                    saveBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .overlay(alignment: .top) {
                if showSavedToast {
                    savedToast
                        .padding(.horizontal, AuraMetrics.pagePadding)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationBarHidden(true)
            .animation(.easeOut(duration: 0.22), value: viewModel.hasChanges)
            .animation(.easeOut(duration: 0.22), value: showSavedToast)
            .onChange(of: viewModel.userName) { _, _ in viewModel.checkChanges() }
            .onChange(of: viewModel.wakeUpTime) { _, _ in viewModel.checkChanges() }
            .onChange(of: viewModel.selectedGenres) { _, _ in viewModel.checkChanges() }
            .onChange(of: viewModel.selectedPlatform) { _, _ in viewModel.checkChanges() }
            .onChange(of: viewModel.selectedSongLanguage) { _, _ in viewModel.checkChanges() }
            .sheet(isPresented: $showAbout) {
                AboutView()
            }
            .onAppear {
                if let profile = firebaseManager.userProfile {
                    viewModel.loadProfile(profile)
                }
                notificationManager.refreshDailyMusicScheduleStatus()
            }
            .alert(isEnglish ? "Delete account?" : "Hesap silinsin mi?", isPresented: $showDeleteConfirmation) {
                Button(isEnglish ? "Cancel" : "Vazgeç", role: .cancel) {}
                Button(isEnglish ? "Delete" : "Sil", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text(isEnglish
                    ? "Your profile and account will be permanently deleted."
                    : "Profilin ve hesabın kalıcı olarak silinecek.")
            }
        }
        .preferredColorScheme(.light)
    }

    private var profileSnapshot: some View {
        HStack(spacing: 0) {
            snapshotItem(
                value: "\(viewModel.selectedGenres.count)",
                label: isEnglish ? "Genres" : "Tür",
                icon: "music.note.list",
                tint: .auraSuccess
            )
            snapshotDivider
            snapshotItem(
                value: "\(favoritesManager.favorites.count)",
                label: isEnglish ? "Liked" : "Beğeni",
                icon: "heart.fill",
                tint: .auraPrimary
            )
            snapshotDivider
            snapshotItem(
                value: "\(historyManager.history.count)",
                label: isEnglish ? "History" : "Geçmiş",
                icon: "clock.arrow.circlepath",
                tint: .auraTertiary
            )
        }
        .padding(.vertical, 14)
        .background(Color.auraSurfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline, lineWidth: 1)
        }
    }

    private var snapshotDivider: some View {
        Rectangle()
            .fill(Color.auraOutline)
            .frame(width: 1, height: 38)
    }

    private func snapshotItem(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.subheadline.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.auraOnSurface)
            }
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Color.auraTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var preferenceSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Language preferences" : "Dil tercihleri",
            subtitle: isEnglish ? "For the interface and recommendations" : "Arayüz ve öneriler için",
            icon: "globe",
            tint: .auraTertiary
        ) {
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEnglish ? "App language" : "Uygulama dili")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.auraOnSurface)
                        Text(isEnglish ? "Applies immediately" : "Anında uygulanır")
                            .font(.caption2)
                            .foregroundStyle(Color.auraTextSecondary)
                    }
                    Spacer()
                    Picker("", selection: $languageManager.currentLanguage) {
                        Text("TR").tag("tr")
                        Text("EN").tag("en")
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 116)
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text(isEnglish ? "Song language" : "Şarkı dili")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.auraTextSecondary)

                    HStack(spacing: 8) {
                        ForEach(SongLanguagePreference.allCases) { option in
                            selectionButton(
                                title: option.title(isEnglish: isEnglish),
                                isSelected: viewModel.selectedSongLanguage == option
                            ) {
                                viewModel.selectedSongLanguage = option
                            }
                        }
                    }
                }
            }
        }
    }

    private var personalSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Personal details" : "Kişisel bilgiler",
            subtitle: isEnglish ? "Used to tailor your daily experience" : "Günlük deneyimini kişiselleştirmek için",
            icon: "person.fill",
            tint: .auraPrimary
        ) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(isEnglish ? "Your name" : "Adın")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.auraTextSecondary)
                    HStack(spacing: 10) {
                        Image(systemName: "person")
                            .foregroundStyle(isNameFocused ? Color.auraPrimary : Color.auraTextSecondary)
                            .frame(width: 20)
                        TextField(isEnglish ? "e.g. Alex" : "Örn: Aysu", text: $viewModel.userName)
                            .focused($isNameFocused)
                            .textContentType(.name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { isNameFocused = false }
                    }
                    .auraField(isFocused: isNameFocused)
                }

                Divider()

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(isEnglish ? "Wake-up time" : "Uyanma saati")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.auraOnSurface)
                        Text(isEnglish ? "Daily recommendation time" : "Günlük öneri saati")
                            .font(.caption)
                            .foregroundStyle(Color.auraTextSecondary)
                    }
                    Spacer()
                    DatePicker("", selection: $viewModel.wakeUpTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .tint(.auraPrimary)
                }
            }
        }
    }

    private var genreSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Favorite genres" : "Sevdiğin türler",
            subtitle: isEnglish
                ? "Selected \(viewModel.selectedGenres.count) of \(Profile.maxGenreSelection)"
                : "\(Profile.maxGenreSelection) türden \(viewModel.selectedGenres.count) seçildi",
            icon: "music.note.list",
            tint: .auraSuccess
        ) {
            LazyVGrid(columns: genreColumns, spacing: 8) {
                ForEach(viewModel.availableGenres, id: \.self) { genre in
                    let isSelected = viewModel.selectedGenres.contains(genre)
                    Button {
                        withAnimation(.easeOut(duration: 0.16)) {
                            viewModel.toggleGenre(genre)
                            viewModel.checkChanges()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.caption2.weight(.bold))
                            }
                            Text(LocalizedStringKey(genre))
                                .font(.caption.weight(.semibold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.auraOnSurface)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 7)
                        .background(isSelected ? Color.auraSuccess : Color.auraSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                .stroke(isSelected ? Color.auraSuccess : Color.auraOutline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var dailyMusicNotificationSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Daily music notification" : "Günlük müzik bildirimi",
            subtitle: String(
                format: isEnglish ? "Every day at %@" : "Her gün %@ saatinde",
                notificationTimeText
            ),
            icon: "bell.badge.fill",
            tint: notificationStatusColor
        ) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: notificationStatusIcon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(notificationStatusColor)
                        .frame(width: 36, height: 36)
                        .background(notificationStatusColor.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(notificationStatusTitle)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.auraOnSurface)
                        Text(notificationStatusDetail)
                            .font(.caption)
                            .foregroundStyle(Color.auraTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                if isDailyMusicScheduleCurrent {
                    Button(action: sendTestNotification) {
                        Label(
                            isEnglish ? "Send test in 5 seconds" : "5 saniye içinde test gönder",
                            systemImage: "paperplane.fill"
                        )
                    }
                    .buttonStyle(M3TonalButton())
                } else if notificationManager.dailyMusicScheduleStatus == .scheduled {
                    Button(action: saveChanges) {
                        Label(
                            isEnglish ? "Save new notification time" : "Yeni bildirim saatini kaydet",
                            systemImage: "clock.badge.checkmark.fill"
                        )
                    }
                    .buttonStyle(M3FilledButton(tint: .auraWarning))
                } else {
                    Button(action: repairDailyMusicNotification) {
                        Label(
                            isEnglish ? "Enable and repair" : "Etkinleştir ve düzelt",
                            systemImage: "wrench.and.screwdriver.fill"
                        )
                    }
                    .buttonStyle(M3FilledButton())
                }

                if let notificationTestMessage {
                    Text(notificationTestMessage)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(notificationStatusColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity)
                }
            }
        }
    }

    private var notificationTimeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: languageManager.currentLanguage)
        formatter.timeStyle = .short
        return formatter.string(from: scheduledNotificationDate ?? viewModel.wakeUpTime)
    }

    private var scheduledNotificationDate: Date? {
        guard let scheduled = notificationManager.dailyMusicScheduledComponents,
              let hour = scheduled.hour,
              let minute = scheduled.minute else { return nil }
        return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: Date())
    }

    private var isDailyMusicScheduleCurrent: Bool {
        guard notificationManager.dailyMusicScheduleStatus == .scheduled,
              let scheduled = notificationManager.dailyMusicScheduledComponents else { return false }
        let draft = Calendar.current.dateComponents([.hour, .minute], from: viewModel.wakeUpTime)
        return scheduled.hour == draft.hour && scheduled.minute == draft.minute
    }

    private var notificationStatusTitle: String {
        switch notificationManager.dailyMusicScheduleStatus {
        case .checking:
            return isEnglish ? "Checking schedule" : "Plan kontrol ediliyor"
        case .scheduled:
            return isDailyMusicScheduleCurrent
                ? (isEnglish ? "Daily schedule is active" : "Günlük plan aktif")
                : (isEnglish ? "New time is not saved" : "Yeni saat henüz kaydedilmedi")
        case .permissionRequired:
            return isEnglish ? "Notification permission required" : "Bildirim izni gerekli"
        case .missing:
            return isEnglish ? "Daily schedule is missing" : "Günlük plan eksik"
        case .failed:
            return isEnglish ? "Schedule could not be created" : "Plan oluşturulamadı"
        }
    }

    private var notificationStatusDetail: String {
        switch notificationManager.dailyMusicScheduleStatus {
        case .scheduled:
            return isDailyMusicScheduleCurrent
                ? (isEnglish
                    ? "AuraTune will keep one repeating notification scheduled."
                    : "AuraTune tekrar eden tek bildirimi sürekli planlı tutar.")
                : (isEnglish
                    ? "Save changes to move the active notification to the new time."
                    : "Aktif bildirimi yeni saate taşımak için değişiklikleri kaydet.")
        case .permissionRequired:
            return isEnglish
                ? "Allow alerts so the daily song can reach you."
                : "Günün şarkısının ulaşması için bildirimlere izin ver."
        case .checking:
            return isEnglish ? "Reading the system notification plan." : "Sistem bildirim planı okunuyor."
        case .missing, .failed:
            return isEnglish
                ? "Repair the schedule without losing your latest song."
                : "Son şarkını kaybetmeden planı yeniden kur."
        }
    }

    private var notificationStatusIcon: String {
        switch notificationManager.dailyMusicScheduleStatus {
        case .scheduled: return isDailyMusicScheduleCurrent ? "checkmark.circle.fill" : "clock.badge.exclamationmark.fill"
        case .checking: return "clock.fill"
        case .permissionRequired: return "bell.slash.fill"
        case .missing, .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var notificationStatusColor: Color {
        switch notificationManager.dailyMusicScheduleStatus {
        case .scheduled: return isDailyMusicScheduleCurrent ? .auraSuccess : .auraWarning
        case .checking: return .auraSecondary
        case .permissionRequired, .missing, .failed: return .auraDanger
        }
    }

    private var draftProfile: Profile {
        Profile(
            name: viewModel.userName,
            wakeUpTime: viewModel.wakeUpTime,
            genres: Array(viewModel.selectedGenres),
            platform: viewModel.selectedPlatform,
            songLanguage: viewModel.selectedSongLanguage
        )
    }

    private func repairDailyMusicNotification() {
        notificationTestMessage = nil
        notificationManager.requestAuthorization { granted in
            if granted {
                notificationManager.ensureDailyMusicNotification(for: draftProfile)
                return
            }

            notificationTestMessage = isEnglish
                ? "Enable notifications in Settings, then try again."
                : "Bildirimleri Ayarlar'dan açıp tekrar dene."
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func sendTestNotification() {
        notificationTestMessage = nil
        notificationManager.scheduleDailyMusicTest(for: draftProfile) { success in
            withAnimation {
                notificationTestMessage = success
                    ? (isEnglish ? "Test notification will arrive in 5 seconds." : "Test bildirimi 5 saniye içinde gelecek.")
                    : (isEnglish ? "Test could not be scheduled." : "Test bildirimi planlanamadı.")
            }
        }
    }

    private var platformSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Listening service" : "Müzik uygulaması",
            subtitle: isEnglish ? "Songs open directly in this app" : "Şarkılar doğrudan bu uygulamada açılır",
            icon: "headphones",
            tint: .auraSecondary
        ) {
            VStack(spacing: 8) {
                ForEach(viewModel.availablePlatforms, id: \.self) { platform in
                    let isSelected = viewModel.selectedPlatform == platform
                    Button {
                        viewModel.selectedPlatform = platform
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: platformIcon(platform))
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(isSelected ? Color.white : Color.auraTextSecondary)
                                .frame(width: 36, height: 36)
                                .background(isSelected ? Color.auraDeepAccent : Color.auraSurface)
                                .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                            Text(platform)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.auraOnSurface)
                            Spacer()
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 20))
                                .foregroundStyle(isSelected ? Color.auraPrimary : Color.auraOutline)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 56)
                        .background(isSelected ? Color.auraPrimary.opacity(0.07) : Color.auraSurface)
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                                .stroke(isSelected ? Color.auraPrimary.opacity(0.35) : Color.auraOutline, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var aboutRow: some View {
        Button {
            showAbout = true
        } label: {
            HStack(spacing: 12) {
                AuraIconBadge(icon: "info.circle.fill", tint: .auraTertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEnglish ? "About AuraTune" : "AuraTune hakkında")
                        .font(.auraSectionTitle)
                        .foregroundStyle(Color.auraOnSurface)
                    Text(isEnglish ? "Version, features and credits" : "Sürüm, özellikler ve bilgiler")
                        .font(.caption)
                        .foregroundStyle(Color.auraTextSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.auraTextSecondary)
            }
            .auraCardSurface()
        }
        .buttonStyle(.plain)
    }

    private var accountSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Account" : "Hesap",
            subtitle: firebaseManager.currentUser?.email,
            icon: "person.crop.circle",
            tint: .auraTextSecondary
        ) {
            VStack(spacing: 10) {
                Button {
                    do {
                        try firebaseManager.signOut()
                    } catch {
                        authActionError = error.localizedDescription
                    }
                } label: {
                    Label(isEnglish ? "Log out" : "Çıkış yap", systemImage: "rectangle.portrait.and.arrow.right")
                }
                .buttonStyle(M3TonalButton())

                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 9) {
                        if isDeletingAccount {
                            ProgressView()
                                .tint(.auraDanger)
                        } else {
                            Image(systemName: "trash")
                        }
                        Text(isEnglish ? "Delete account" : "Hesabı sil")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.auraDanger)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(Color.auraDanger.opacity(0.07))
                    .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous)
                            .stroke(Color.auraDanger.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isDeletingAccount)
            }
        }
    }

    private func selectionButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : Color.auraOnSurface)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isSelected ? Color.auraTertiary : Color.auraSurface)
                .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                        .stroke(isSelected ? Color.auraTertiary : Color.auraOutline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: saveChanges) {
                HStack(spacing: 9) {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark")
                    }
                    Text(viewModel.isSaving
                        ? (isEnglish ? "Saving..." : "Kaydediliyor...")
                        : (isEnglish ? "Save changes" : "Değişiklikleri kaydet"))
                }
            }
            .buttonStyle(M3FilledButton())
            .disabled(viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.isSaving)
            .padding(.horizontal, AuraMetrics.pagePadding)
            .padding(.vertical, 12)
            .auraContentColumn()
        }
        .background(.ultraThinMaterial)
    }

    private var savedToast: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.auraSuccess)
            Text(isEnglish ? "Changes saved" : "Değişiklikler kaydedildi")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.auraOnSurface)
            Spacer()
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline, lineWidth: 1)
        }
        .shadow(color: Color.auraDeepAccent.opacity(0.12), radius: 12, y: 5)
    }

    private func errorPanel(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message)
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color.auraDanger)
        .padding(14)
        .background(Color.auraDanger.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
    }

    private func saveChanges() {
        isNameFocused = false
        authActionError = nil
        Task {
            do {
                try await viewModel.saveSettings()
                withAnimation { showSavedToast = true }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation { showSavedToast = false }
            } catch {
                authActionError = isEnglish
                    ? "Changes could not be saved. Check your connection and try again."
                    : "Değişiklikler kaydedilemedi. Bağlantını kontrol edip tekrar dene."
            }
        }
    }

    private func deleteAccount() {
        Task {
            isDeletingAccount = true
            do {
                try await firebaseManager.deleteCurrentAccount()
            } catch {
                authActionError = error.localizedDescription
            }
            isDeletingAccount = false
        }
    }

    private func platformIcon(_ platform: String) -> String {
        switch platform {
        case "Spotify": return "music.note"
        case "Apple Music": return "applelogo"
        case "YouTube Music": return "play.rectangle.fill"
        default: return "headphones"
        }
    }
}