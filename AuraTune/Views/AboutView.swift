import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    var isEnglish: Bool { languageManager.currentLanguage == "en" }

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.auraSurface.ignoresSafeArea()
                LinearGradient(
                    colors: [Color(hex: "994A1A"), Color.auraPrimary, Color(hex: "FFD966").opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 220)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(edges: .top)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {

                        // Hero Header
                        ZStack(alignment: .bottomLeading) {
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .frame(width: 200, height: 200)
                                .offset(x: 200, y: -20)
                            Circle()
                                .fill(Color.white.opacity(0.04))
                                .frame(width: 80, height: 80)
                                .offset(x: -20, y: -60)

                            // Close button top-right
                            HStack {
                                Spacer()
                                Button(action: { dismiss() }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.trailing, 20)
                                .padding(.top, 8)
                            }
                            .frame(maxHeight: .infinity, alignment: .top)

                            VStack(alignment: .leading, spacing: 6) {
                                Text(isEnglish ? "About" : "Hakkında")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85))
                                Text("AuraTune")
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                Text("v\(appVersion) (\(isEnglish ? "Build" : "Derleme") \(buildNumber))")
                                    .font(.caption.weight(.medium))
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                        .frame(height: 200)
                        .frame(maxWidth: .infinity, alignment: .leading)

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
                        Text("Made with ❤️ Erdinç Yılmaz")
                            .font(.footnote)
                            .foregroundColor(.auraOnSurface.opacity(0.4))
                            .padding(.bottom, 40)
                    }
                    .padding(.horizontal, 16)
                }
            }
            .navigationBarHidden(true)
        }
        .presentationDragIndicator(.visible)
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
