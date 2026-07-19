import SwiftUI
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var remindersManager: RemindersManager
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showNotificationBanner = false
    @State private var selectedTab = 0
    @State private var notificationAuthorizationStatus: UNAuthorizationStatus = .notDetermined

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }

    private var tabItems: [AuraTabBarItem] {
        [
            AuraTabBarItem(id: 0, title: isEnglish ? "Home" : "Ana Sayfa", icon: "house", selectedIcon: "house.fill"),
            AuraTabBarItem(id: 1, title: isEnglish ? "Discover" : "Keşfet", icon: "safari", selectedIcon: "safari.fill"),
            AuraTabBarItem(id: 2, title: isEnglish ? "Reminders" : "Hatırlatıcı", icon: "bell", selectedIcon: "bell.fill"),
            AuraTabBarItem(id: 3, title: isEnglish ? "Library" : "Kütüphane", icon: "heart", selectedIcon: "heart.fill"),
            AuraTabBarItem(id: 4, title: isEnglish ? "Profile" : "Profil", icon: "person", selectedIcon: "person.fill")
        ]
    }

    var body: some View {
        ZStack {
            Color.auraSurface.ignoresSafeArea()
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)

                DiscoverView()
                    .tag(1)

                RemindersView()
                    .tag(2)

                FavoritesView()
                    .tag(3)

                SettingsView()
                    .tag(4)
            }
            .toolbar(.hidden, for: .tabBar)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if let prompt = notificationManager.foregroundPrompt,
                       prompt.origin == .foregroundDelivery {
                        foregroundPromptCard(prompt)
                            .padding(.horizontal, 14)
                            .auraContentColumn(maxWidth: 600)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    AuraTabBar(selection: $selectedTab, items: tabItems)
                }
            }

            // Notification permission banner — visible on all tabs
            if showNotificationBanner {
                VStack {
                    notificationPermissionBanner
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                        .auraContentColumn()
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }

            if let prompt = notificationManager.foregroundPrompt,
               prompt.origin == .notificationTap {
                ZStack {
                    Color.black.opacity(0.35)
                        .ignoresSafeArea()
                    foregroundPromptCard(prompt)
                        .padding(.horizontal, 18)
                        .auraContentColumn(maxWidth: 600)
                }
                .transition(.opacity)
                .zIndex(1001)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: notificationManager.foregroundPrompt?.id)
        .onAppear {
            checkNotificationPermission()
            notificationManager.refreshDailyMusicScheduleStatus()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                checkNotificationPermission()
            }
        }
        .onChange(of: languageManager.currentLanguage) { _, _ in
            if let profile = FirebaseManager.shared.userProfile {
                notificationManager.ensureDailyMusicNotification(for: profile)
            }
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationAuthorizationStatus = settings.authorizationStatus
                notificationManager.refreshDailyMusicScheduleStatus()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showNotificationBanner = (settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined)
                }
            }
        }
    }

    private var notificationPermissionBanner: some View {
        HStack(spacing: 12) {
            AuraIconBadge(
                icon: notificationAuthorizationStatus == .denied ? "bell.slash.fill" : "bell.badge.fill",
                tint: notificationAuthorizationStatus == .denied ? .auraDanger : .auraPrimary
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(notificationAuthorizationStatus == .denied
                    ? (isEnglish ? "Notifications are off" : "Bildirimler kapalı")
                    : (isEnglish ? "Stay in rhythm" : "Ritmini kaçırma"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.auraOnSurface)
                Text(notificationAuthorizationStatus == .denied
                    ? (isEnglish ? "Enable alerts in Settings." : "Uyarıları Ayarlar'dan etkinleştir.")
                    : (isEnglish ? "Allow daily song and reminder alerts." : "Günlük şarkı ve hatırlatıcı uyarılarına izin ver."))
                    .font(.caption)
                    .foregroundColor(.auraTextSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Button(action: handleNotificationPermissionAction) {
                Text(notificationAuthorizationStatus == .denied
                    ? (isEnglish ? "Settings" : "Ayarlar")
                    : (isEnglish ? "Allow" : "İzin ver"))
                    .font(.caption.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .frame(minHeight: AuraMetrics.minimumTapTarget)
                    .background(Color.auraPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showNotificationBanner = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.auraTextSecondary)
                    .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isEnglish ? "Dismiss" : "Kapat")
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline, lineWidth: 1)
        }
        .shadow(color: Color.auraDeepAccent.opacity(0.12), radius: 12, x: 0, y: 5)
    }

    private func handleNotificationPermissionAction() {
        if notificationAuthorizationStatus == .notDetermined {
            notificationManager.requestAuthorization { granted in
                withAnimation(.easeOut(duration: 0.2)) {
                    showNotificationBanner = !granted
                }
                checkNotificationPermission()
            }
            return
        }

        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func foregroundPromptCard(_ prompt: NotificationManager.ForegroundPrompt) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AuraIconBadge(
                    icon: prompt.type == .water ? "drop.fill" : "pills.fill",
                    tint: prompt.type == .water ? .auraTertiary : .auraPrimary
                )
                Text(prompt.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.auraOnSurface)
                Spacer()
                Button(action: {
                    notificationManager.dismissForegroundPrompt()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundColor(.auraTextSecondary)
                        .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                }
                .buttonStyle(.plain)
            }

            Text(prompt.body)
                .font(.caption)
                .foregroundColor(.auraTextSecondary)
                .lineLimit(3)

            HStack(spacing: 10) {
                if prompt.type == .water {
                    quickActionButton(
                        title: isEnglish ? "I Drank" : "İçtim",
                        color: .auraSuccess
                    ) {
                        notificationManager.handleForegroundWaterAction(didDrink: true)
                    }

                    if remindersManager.hasUnlockedSmartSnooze {
                        quickActionButton(
                            title: isEnglish ? "In 15 Min" : "15 Dk Sonra",
                            color: .auraTertiary
                        ) {
                            notificationManager.snoozeForegroundWaterReminder()
                        }
                    } else {
                        quickActionButton(
                            title: isEnglish ? "Not Now" : "Şimdi Değil",
                            color: .auraTextSecondary
                        ) {
                            notificationManager.handleForegroundWaterAction(didDrink: false)
                        }
                    }
                } else {
                    quickActionButton(
                        title: isEnglish ? "I Took It" : "Aldım",
                        color: .auraSuccess
                    ) {
                        notificationManager.handleForegroundMedicineAction(tookMedicine: true)
                    }

                    quickActionButton(
                        title: isEnglish ? "Skip" : "Atladım",
                        color: .auraDanger
                    ) {
                        notificationManager.handleForegroundMedicineAction(tookMedicine: false)
                    }
                }
            }
        }
        .padding(14)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline, lineWidth: 1)
        }
        .shadow(color: Color.auraDeepAccent.opacity(0.18), radius: 14, x: 0, y: 6)
    }

    private func quickActionButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AuraMetrics.minimumTapTarget)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
