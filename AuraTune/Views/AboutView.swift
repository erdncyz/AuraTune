import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {

                    // App Icon + Name
                    VStack(spacing: 14) {
                        ZStack {
                            LinearGradient(
                                colors: [Color(hex: "994A1A"), Color.auraPrimary, Color(hex: "FFD966").opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: Color.auraPrimary.opacity(0.4), radius: 16, x: 0, y: 8)

                            Image(systemName: "music.note")
                                .font(.system(size: 40, weight: .semibold))
                                .foregroundColor(.white)
                        }

                        Text("AuraTune")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.auraOnSurface)

                        Text("v\(appVersion) (\(isEnglish ? "Build" : "Derleme") \(buildNumber))")
                            .font(.subheadline)
                            .foregroundColor(.auraOnSurface.opacity(0.5))
                    }
                    .padding(.top, 32)

                    // Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.auraPrimary.opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "sparkles")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.auraPrimary)
                            }
                            Text(isEnglish ? "What is AuraTune?" : "AuraTune Nedir?")
                                .font(.headline)
                                .foregroundColor(.auraOnSurface)
                        }

                        Text(isEnglish
                            ? "AuraTune is an AI-powered daily music recommendation app. Every morning, it analyzes your mood, wake-up time, and favorite genres to suggest the perfect song to start your day.\n\nWith the Discover tab, you can also explore music based on how you're feeling right now — whether energetic, calm, focused, or nostalgic."
                            : "AuraTune, yapay zeka destekli günlük müzik öneri uygulamasıdır. Her sabah ruh halini, uyanma saatini ve sevdiğin müzik türlerini analiz ederek güne mükemmel bir şarkıyla başlamanı sağlar.\n\nKeşfet sekmesiyle şu anki hissine göre — enerjik, sakin, odaklanmış ya da nostaljik — müzik keşfedebilirsin."
                        )
                        .font(.subheadline)
                        .foregroundColor(.auraOnSurface.opacity(0.75))
                        .lineSpacing(4)
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

                    // Features
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(hex: "34C759").opacity(0.15))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Color(hex: "34C759"))
                            }
                            Text(isEnglish ? "Features" : "Özellikler")
                                .font(.headline)
                                .foregroundColor(.auraOnSurface)
                        }

                        ForEach(features, id: \.0) { icon, title, desc in
                            HStack(alignment: .top, spacing: 12) {
                                Text(icon)
                                    .font(.title3)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(title)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.auraOnSurface)
                                    Text(desc)
                                        .font(.caption)
                                        .foregroundColor(.auraOnSurface.opacity(0.6))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)

                    // Footer
                    Text("Made with Erdinç Yılmaz")
                        .font(.footnote)
                        .foregroundColor(.auraOnSurface.opacity(0.4))
                        .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
            }
            .background(Color.auraSurface.ignoresSafeArea())
            .navigationTitle(isEnglish ? "About" : "Hakkında")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.auraOnSurface.opacity(0.4))
                    }
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Feature list
    private var features: [(String, String, String)] {
        isEnglish ? [
            ("🎵", "Daily Song", "AI picks the perfect track every morning"),
            ("🎯", "Mood Discovery", "Find music based on how you feel right now"),
            ("🔔", "Morning Alarm", "Wake up to your personalized song notification"),
            ("🌍", "TR / EN", "Full Turkish and English support")
        ] : [
            ("🎵", "Günlük Şarkı", "Yapay zeka her sabah mükemmel parçayı seçer"),
            ("🎯", "Ruh Hali Keşfi", "Şu an nasıl hissettiğine göre müzik bul"),
            ("🔔", "Sabah Alarmı", "Kişiselleştirilmiş şarkı bildiriminle uyan"),
            ("🌍", "TR / EN", "Tam Türkçe ve İngilizce destek")
        ]
    }
}

#Preview {
    AboutView()
        .environmentObject(LanguageManager.shared)
}
