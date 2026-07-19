import SwiftUI

/// High-emphasis action used once per content section.
struct M3FilledButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    var tint: Color = .auraPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isEnabled ? tint : Color.auraOutline)
            .foregroundColor(isEnabled ? .white : .auraTextSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
            .shadow(
                color: isEnabled ? tint.opacity(0.24) : .clear,
                radius: configuration.isPressed ? 2 : 8,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct M3TonalButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Color.auraPrimary.opacity(isEnabled ? 0.1 : 0.05))
            .foregroundColor(isEnabled ? .auraPrimaryDark : .auraTextSecondary)
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AuraMetrics.controlRadius, style: .continuous)
                    .stroke(Color.auraPrimary.opacity(isEnabled ? 0.18 : 0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}
