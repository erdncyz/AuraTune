import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var languageManager: LanguageManager

    private let notifications: [AppNotification] = [
        AppNotification(
            icon: "sparkles", iconColor: Color(hex: "7C6AF7"),
            title: "Günün Önerisi Hazır!", titleEn: "Daily Suggestion Ready!",
            body: "Sabah enerjin için \"Blinding Lights\" - The Weeknd seçildi.",
            bodyEn: "\"Blinding Lights\" - The Weeknd selected for your morning energy.",
            timeAgo: "Bugün, 07:00", timeAgoEn: "Today, 07:00", isNew: true
        ),
        AppNotification(
            icon: "alarm.fill", iconColor: Color(hex: "F4845F"),
            title: "Alarm Kuruldu", titleEn: "Alarm Set",
            body: "Yarın sabah 07:00 için alarmın hazır.",
            bodyEn: "Your alarm is set for tomorrow at 07:00.",
            timeAgo: "Dün, 22:15", timeAgoEn: "Yesterday, 22:15", isNew: true
        ),
        AppNotification(
            icon: "music.note", iconColor: Color(hex: "34C759"),
            title: "Yeni Tür Denemesi", titleEn: "New Genre Discovery",
            body: "Lo-Fi türünde yeni parçalar seni bekliyor!",
            bodyEn: "New Lo-Fi tracks are waiting for you!",
            timeAgo: "2 gün önce", timeAgoEn: "2 days ago", isNew: false
        ),
        AppNotification(
            icon: "bell.badge.fill", iconColor: Color(hex: "FF3B30"),
            title: "Haftalık Özet", titleEn: "Weekly Summary",
            body: "Bu hafta 5 farklı şarkı dinledin. Harika gidiyorsun!",
            bodyEn: "You listened to 5 different songs this week. Keep it up!",
            timeAgo: "3 gün önce", timeAgoEn: "3 days ago", isNew: false
        ),
        AppNotification(
            icon: "heart.fill", iconColor: Color(hex: "FF2D55"),
            title: "Favori Tür: Pop", titleEn: "Favorite Genre: Pop",
            body: "Pop türü bu ay en çok önerilen türün oldu.",
            bodyEn: "Pop was your most recommended genre this month.",
            timeAgo: "1 hafta önce", timeAgoEn: "1 week ago", isNew: false
        )
    ]

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // ── Hero Banner ──────────────────────────────────
                        notifHero

                        // ── Notification List ────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {

                            // "New" section
                            let newNotifs = notifications.filter { $0.isNew }
                            let oldNotifs = notifications.filter { !$0.isNew }

                            if !newNotifs.isEmpty {
                                sectionLabel(isEnglish ? "New" : "Yeni")
                                ForEach(newNotifs) { n in
                                    NotificationRow(notif: n, isEnglish: isEnglish)
                                }
                            }

                            if !oldNotifs.isEmpty {
                                sectionLabel(isEnglish ? "Earlier" : "Daha Önce")
                                    .padding(.top, 4)
                                ForEach(oldNotifs) { n in
                                    NotificationRow(notif: n, isEnglish: isEnglish)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Hero
    private var notifHero: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [Color(hex: "7C6AF7"), Color(hex: "A78BFA"), Color(hex: "C4B5FD").opacity(0.7)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea(edges: .top)
            .frame(height: 210)

            Circle().fill(Color.white.opacity(0.06)).frame(width: 180).offset(x: 230, y: -10)
            Circle().fill(Color.white.opacity(0.04)).frame(width: 120).offset(x: 280, y: 40)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.2)).frame(width: 40, height: 40)
                        Image(systemName: "bell.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEnglish ? "Notifications" : "Bildirimler")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(isEnglish
                             ? "\(notifications.filter { $0.isNew }.count) new"
                             : "\(notifications.filter { $0.isNew }.count) yeni bildirim")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.bold())
            .tracking(0.8)
            .foregroundColor(.auraOnSurface.opacity(0.4))
    }
}

// MARK: - Notification Model
struct AppNotification: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let title: String
    let titleEn: String
    let body: String
    let bodyEn: String
    let timeAgo: String
    let timeAgoEn: String
    var isNew: Bool = false
}

// MARK: - Notification Row Card
struct NotificationRow: View {
    let notif: AppNotification
    let isEnglish: Bool
    @State private var isPressed = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon bubble
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(notif.iconColor.opacity(0.13))
                    .frame(width: 50, height: 50)
                Image(systemName: notif.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(notif.iconColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(isEnglish ? notif.titleEn : notif.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.auraOnSurface)
                    Spacer()
                    if notif.isNew {
                        Circle()
                            .fill(notif.iconColor)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(isEnglish ? notif.bodyEn : notif.body)
                    .font(.subheadline)
                    .foregroundColor(.auraOnSurface.opacity(0.65))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(isEnglish ? notif.timeAgoEn : notif.timeAgo)
                    .font(.caption2)
                    .foregroundColor(.auraOnSurface.opacity(0.38))
                    .padding(.top, 2)
            }
        }
        .padding(14)
        .background(notif.isNew ? Color.white : Color.white.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    notif.isNew
                        ? notif.iconColor.opacity(0.18)
                        : Color.auraOnSurface.opacity(0.07),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(notif.isNew ? 0.06 : 0.03), radius: notif.isNew ? 10 : 6, x: 0, y: 3)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        .onTapGesture {
            withAnimation { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation { isPressed = false }
            }
        }
    }
}
