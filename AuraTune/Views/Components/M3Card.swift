import SwiftUI

/// Quiet elevated surface for grouped content.
struct M3Card<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(AuraMetrics.cardPadding)
            .background(Color.auraSurfaceVariant)
            .clipShape(RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AuraMetrics.cardRadius, style: .continuous)
                    .stroke(Color.auraOutline.opacity(0.8), lineWidth: 1)
            )
            .shadow(color: Color.auraDeepAccent.opacity(0.05), radius: 12, x: 0, y: 5)
    }
}
