import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var languageManager: LanguageManager

    private var isEnglish: Bool { languageManager.currentLanguage == "en" }
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            AuraFixedHeaderLayout {
                AuraPageHeader(
                    eyebrow: isEnglish ? "About" : "Hakkında",
                    title: "AuraTune",
                    subtitle: "v\(appVersion) · \(isEnglish ? "Build" : "Derleme") \(buildNumber)",
                    icon: "waveform",
                    accent: .auraSecondary
                )
            } content: {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AuraMetrics.sectionSpacing) {
                        storySection
                        featuresSection
                        footer
                    }
                    .padding(.horizontal, AuraMetrics.pagePadding)
                    .padding(.top, 22)
                    .padding(.bottom, 36)
                    .auraContentColumn()
                }
            }
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: AuraMetrics.minimumTapTarget, height: AuraMetrics.minimumTapTarget)
                        .background(Color.white.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isEnglish ? "Close" : "Kapat")
                .padding(.top, 8)
                .padding(.trailing, 14)
            }
            .navigationBarHidden(true)
        }
        .presentationDragIndicator(.visible)
        .preferredColorScheme(.light)
    }

    private var storySection: some View {
        AuraSectionCard(
            title: isEnglish ? "Music that meets the moment" : "Anına eşlik eden müzik",
            icon: "sparkles",
            tint: .auraPrimary
        ) {
            Text(isEnglish
                ? "AuraTune pairs your preferences, daily rhythm and current mood with a song worth hearing. Your daily pick and every discovery stay close in one personal library."
                : "AuraTune; tercihlerini, günlük ritmini ve o anki ruh halini dinlemeye değer bir şarkıyla buluşturur. Günlük önerin ve tüm keşiflerin kişisel kütüphanende bir arada kalır.")
                .font(.subheadline)
                .foregroundStyle(Color.auraTextSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var featuresSection: some View {
        AuraSectionCard(
            title: isEnglish ? "Inside AuraTune" : "AuraTune'da",
            icon: "square.grid.2x2",
            tint: .auraTertiary
        ) {
            VStack(spacing: 0) {
                ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                    HStack(alignment: .top, spacing: 12) {
                        AuraIconBadge(icon: feature.icon, tint: feature.tint)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(feature.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.auraOnSurface)
                            Text(feature.description)
                                .font(.caption)
                                .foregroundStyle(Color.auraTextSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 11)

                    if index < features.count - 1 {
                        Divider().padding(.leading, 48)
                    }
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack(spacing: 5) {
                Text(isEnglish ? "Made with care by" : "Özenle geliştiren")
                Image(systemName: "heart.fill")
                    .foregroundStyle(Color.auraPrimary)
                Text("Erdinç Yılmaz")
            }
            .font(.footnote.weight(.medium))
            .foregroundStyle(Color.auraTextSecondary)

            Text("© 2026 AuraTune")
                .font(.caption2)
                .foregroundStyle(Color.auraTextSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var features: [AboutFeature] {
        if isEnglish {
            return [
                AboutFeature(icon: "sunrise.fill", tint: .auraSecondary, title: "Daily pick", description: "A fresh recommendation shaped by your profile"),
                AboutFeature(icon: "face.smiling", tint: .auraTertiary, title: "Mood discovery", description: "Music matched to how you feel right now"),
                AboutFeature(icon: "bell.badge.fill", tint: .auraPrimary, title: "Personal reminders", description: "Hydration, medicine and morning notifications"),
                AboutFeature(icon: "heart.text.square.fill", tint: .auraSuccess, title: "One library", description: "Liked songs and recommendation history together")
            ]
        }

        return [
            AboutFeature(icon: "sunrise.fill", tint: .auraSecondary, title: "Günlük öneri", description: "Profiline göre şekillenen yeni bir şarkı"),
            AboutFeature(icon: "face.smiling", tint: .auraTertiary, title: "Ruh hali keşfi", description: "O an nasıl hissettiğine uygun müzik"),
            AboutFeature(icon: "bell.badge.fill", tint: .auraPrimary, title: "Kişisel hatırlatıcılar", description: "Su, ilaç ve sabah bildirimleri"),
            AboutFeature(icon: "heart.text.square.fill", tint: .auraSuccess, title: "Tek kütüphane", description: "Beğeniler ve öneri geçmişi bir arada")
        ]
    }
}

private struct AboutFeature: Identifiable {
    let id = UUID()
    let icon: String
    let tint: Color
    let title: String
    let description: String
}

#Preview {
    AboutView()
        .environmentObject(LanguageManager.shared)
}