import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var languageManager: LanguageManager

    private let notifications: [AppNotification] = [
        AppNotification(
            icon: "sparkles", iconColor: .auraTertiary,
            title: "Günün Önerisi Hazır!", titleEn: "Daily Suggestion Ready!",
            body: "Sabah enerjin için \"Blinding Lights\" - The Weeknd seçildi.",
            bodyEn: "\"Blinding Lights\" - The Weeknd selected for your morning energy.",
            timeAgo: "Bugün, 07:00", timeAgoEn: "Today, 07:00", isNew: true
        ),
        AppNotification(
            icon: "alarm.fill", iconColor: .auraPrimary,
            title: "Alarm Kuruldu", titleEn: "Alarm Set",
            body: "Yarın sabah 07:00 için alarmın hazır.",
            bodyEn: "Your alarm is set for tomorrow at 07:00.",
            timeAgo: "Dün, 22:15", timeAgoEn: "Yesterday, 22:15", isNew: true
        ),
        AppNotification(
            icon: "music.note", iconColor: .auraSuccess,
            title: "Yeni Tür Denemesi", titleEn: "New Genre Discovery",
            body: "Lo-Fi türünde yeni parçalar seni bekliyor!",
            bodyEn: "New Lo-Fi tracks are waiting for you!",
            timeAgo: "2 gün önce", timeAgoEn: "2 days ago", isNew: false
        ),
        AppNotification(
            icon: "chart.bar.fill", iconColor: .auraSecondary,
            title: "Haftalık Özet", titleEn: "Weekly Summary",
            body: "Bu hafta 5 farklı şarkı dinledin.",
            bodyEn: "You listened to 5 different songs this week.",
            timeAgo: "3 gün önce", timeAgoEn: "3 days ago", isNew: false
        ),
        AppNotification(
            icon: "heart.fill", iconColor: .auraDanger,
            title: "Favori Tür: Pop", titleEn: "Favorite Genre: Pop",
            body: "Pop türü bu ay en çok önerilen türün oldu.",
            bodyEn: "Pop was your most recommended genre this month.",
            timeAgo: "1 hafta önce", timeAgoEn: "1 week ago", isNew: false
        )
    ]

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }
    private var newNotifications: [AppNotification] { notifications.filter(\.isNew) }
    private var earlierNotifications: [AppNotification] { notifications.filter { !$0.isNew } }

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: isEnglish ? "Your updates" : "Güncellemelerin",
                    title: isEnglish ? "Notifications" : "Bildirimler",
                    subtitle: isEnglish
                        ? "\(newNotifications.count) unread"
                        : "\(newNotifications.count) okunmamış bildirim",
                    icon: "bell.fill",
                    accent: .auraSecondary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        if !newNotifications.isEmpty {
                            notificationSection(
                                title: isEnglish ? "New" : "Yeni",
                                items: newNotifications
                            )
                        }

                        if !earlierNotifications.isEmpty {
                            notificationSection(
                                title: isEnglish ? "Earlier" : "Daha önce",
                                items: earlierNotifications
                            )
                        }
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
                    .auraContentColumn()
                }
            }
            .navigationBarHidden(true)
        }
        .preferredColorScheme(.light)
    }

    private func notificationSection(title: String, items: [AppNotification]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.auraTitle)
                    .foregroundStyle(Color.auraOnSurface)
                Spacer()
                Text("\(items.count)")
                    .font(.caption.monospacedDigit().weight(.bold))
                    .foregroundStyle(Color.auraTextSecondary)
            }

            ForEach(items) { notification in
                NotificationRow(notification: notification, isEnglish: isEnglish)
            }
        }
    }
}

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

struct NotificationRow: View {
    let notification: AppNotification
    let isEnglish: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            AuraIconBadge(icon: notification.icon, tint: notification.iconColor)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(isEnglish ? notification.titleEn : notification.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.auraOnSurface)
                    Spacer(minLength: 4)
                    if notification.isNew {
                        Text(isEnglish ? "NEW" : "YENİ")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(0.7)
                            .foregroundStyle(notification.iconColor)
                    }
                }

                Text(isEnglish ? notification.bodyEn : notification.body)
                    .font(.subheadline)
                    .foregroundStyle(Color.auraTextSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text(isEnglish ? notification.timeAgoEn : notification.timeAgo)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.auraTextSecondary.opacity(0.75))
                    .padding(.top, 2)
            }
        }
        .auraCardSurface()
        .overlay(alignment: .leading) {
            if notification.isNew {
                RoundedRectangle(cornerRadius: 2)
                    .fill(notification.iconColor)
                    .frame(width: 3)
                    .padding(.vertical, 9)
            }
        }
        .accessibilityElement(children: .combine)
    }
}