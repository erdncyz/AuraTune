import SwiftUI
import UserNotifications

struct MainTabView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @State private var showNotificationBanner = false

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }

    var body: some View {
        ZStack {
            Color.auraSurface.ignoresSafeArea()
            TabView {
                HomeView()
                    .tabItem {
                        Label(LocalizedStringKey("Anasayfa"), systemImage: "house.fill")
                    }

                DiscoverView()
                    .tabItem {
                        Label(LocalizedStringKey("Keşfet"), systemImage: "safari.fill")
                    }

                FavoritesView()
                    .tabItem {
                        Label(languageManager.currentLanguage == "en" ? "Library" : "Kütüphanem", systemImage: "heart.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label(LocalizedStringKey("Profil"), systemImage: "person.circle.fill")
                    }
            }
            .tint(.auraPrimary)

            // Notification permission banner — visible on all tabs
            if showNotificationBanner {
                VStack {
                    notificationPermissionBanner
                        .padding(.horizontal, 12)
                        .padding(.top, 6)
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(999)
            }
        }
        .onAppear {
            checkNotificationPermission()
        }
    }

    private func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showNotificationBanner = (settings.authorizationStatus == .denied || settings.authorizationStatus == .notDetermined)
                }
            }
        }
    }

    private var notificationPermissionBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 42, height: 42)
                Image(systemName: "bell.badge.slash.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(isEnglish ? "Notifications are off" : "Bildirimler kapalı")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.white)
                Text(isEnglish
                     ? "Turn on to receive your daily song pick!"
                     : "Günlük şarkı önerini almak için bildirimleri aç!")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.9))
            }

            Spacer()

            Button(action: {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }) {
                Text(isEnglish ? "Enable" : "Aç")
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
            }

            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showNotificationBanner = false
                }
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(hex: "C0392B"), Color(hex: "E74C3C"), Color(hex: "F39C12")],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color(hex: "E74C3C").opacity(0.45), radius: 12, x: 0, y: 6)
    }
}
