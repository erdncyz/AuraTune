import SwiftUI

extension Font {
    static var auraDisplay: Font {
        .system(size: 34, weight: .bold, design: .serif)
    }

    static var auraTitle: Font {
        .system(size: 22, weight: .bold, design: .serif)
    }

    static var auraSectionTitle: Font {
        .system(size: 17, weight: .semibold, design: .rounded)
    }
}

struct AuraFixedHeaderLayout<Header: View, Content: View>: View {
    let header: Header
    let content: Content

    init(
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) {
        self.header = header()
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.auraSurface
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                header
                    .zIndex(1)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct AuraPageHeader: View {
    let eyebrow: String?
    let title: String
    let subtitle: String?
    let icon: String?
    let accent: Color

    init(
        eyebrow: String? = nil,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        accent: Color = .auraPrimary
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.accent = accent
    }

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            VStack(alignment: .leading, spacing: 7) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(.auraDisplay)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 4)

            if let icon {
                ZStack {
                    RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                        .fill(accent.opacity(0.18))
                    RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                        .stroke(accent.opacity(0.38), lineWidth: 1)
                    Image(systemName: icon)
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(accent)
                }
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, AuraMetrics.pagePadding)
        .padding(.top, 20)
        .padding(.bottom, 26)
        .auraContentColumn()
        .background {
            ZStack(alignment: .bottomTrailing) {
                Color.auraDeepAccent
                LinearGradient(
                    colors: [accent.opacity(0.2), .clear, Color.black.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                waveform
                    .padding(.trailing, 18)
                    .padding(.bottom, 12)
            }
                    .ignoresSafeArea(edges: .top)
        }
    }

    private var waveform: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach([12, 24, 18, 34, 20, 29, 14, 25], id: \.self) { height in
                Capsule()
                    .fill(Color.white.opacity(0.045))
                    .frame(width: 3, height: CGFloat(height))
            }
        }
        .accessibilityHidden(true)
    }
}

struct AuraSectionCard<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tint: Color
    let content: Content

    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        tint: Color = .auraPrimary,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                AuraIconBadge(icon: icon, tint: tint)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.auraSectionTitle)
                        .foregroundStyle(Color.auraOnSurface)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(Color.auraTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            content
        }
        .padding(AuraMetrics.cardPadding)
        .background(Color.auraSurfaceVariant)
        .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                .stroke(Color.auraOutline.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: Color.auraDeepAccent.opacity(0.045), radius: 12, x: 0, y: 5)
    }
}

struct AuraIconBadge: View {
    let icon: String
    let tint: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}

struct AuraEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let tint: Color

    var body: some View {
        VStack(spacing: 16) {
            AuraIconBadge(icon: icon, tint: tint)
                .scaleEffect(1.35)
                .padding(.bottom, 4)
            Text(title)
                .font(.auraTitle)
                .foregroundStyle(Color.auraOnSurface)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(Color.auraTextSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.vertical, 52)
    }
}

struct AuraFieldModifier: ViewModifier {
    let isFocused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .frame(minHeight: 50)
            .background(Color.auraSurface)
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous)
                    .stroke(isFocused ? Color.auraPrimary : Color.auraOutline, lineWidth: isFocused ? 1.5 : 1)
            }
    }
}

extension View {
    func auraField(isFocused: Bool = false) -> some View {
        modifier(AuraFieldModifier(isFocused: isFocused))
    }

    func auraCardSurface() -> some View {
        padding(AuraMetrics.cardPadding)
            .background(Color.auraSurfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                    .stroke(Color.auraOutline.opacity(0.78), lineWidth: 1)
            }
            .shadow(color: Color.auraDeepAccent.opacity(0.045), radius: 12, x: 0, y: 5)
    }

    func auraContentColumn(maxWidth: CGFloat = AuraMetrics.contentMaxWidth) -> some View {
        frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
    }
}

struct AuraTabBarItem: Identifiable {
    let id: Int
    let title: String
    let icon: String
    let selectedIcon: String
}

struct AuraTabBar: View {
    @Binding var selection: Int
    let items: [AuraTabBarItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isSelected = selection == item.id
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        selection = item.id
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: isSelected ? item.selectedIcon : item.icon)
                            .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                            .frame(height: 22)
                        Text(item.title)
                            .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }
                    .foregroundStyle(isSelected ? Color.auraPrimary : Color.auraTextSecondary)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .overlay(alignment: .top) {
                        Capsule()
                            .fill(isSelected ? Color.auraPrimary : Color.clear)
                            .frame(width: 22, height: 3)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 7)
        .auraContentColumn()
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.auraOutline.opacity(0.75))
                .frame(height: 0.5)
        }
    }
}