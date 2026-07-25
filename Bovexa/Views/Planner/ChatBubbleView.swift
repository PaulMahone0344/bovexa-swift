import SwiftUI

/// Chat-bubbel: gebruiker (teal-verloop, rechts) of AI (glas, links). Fouttoon = rode
/// rand. Geport uit ChatBubble.tsx in ~/Desktop/agenda-app/src/components/chat/.
struct ChatBubbleView: View {
    enum Role { case user, ai }
    enum Tone { case normal, error }

    let role: Role
    let text: String
    var tone: Tone = .normal

    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 18,
            bottomLeadingRadius: role == .user ? 18 : 6,
            bottomTrailingRadius: role == .user ? 6 : 18,
            topTrailingRadius: 18,
            style: .continuous
        )
    }

    var body: some View {
        HStack {
            if role == .user { Spacer(minLength: 32) }
            Text(text)
                .font(BovexaTheme.TypeStyle.subheadline)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, BovexaTheme.Space.md)
                .padding(.vertical, BovexaTheme.Space.sm + 2)
                .background(background)
                .overlay(shape.strokeBorder(borderColor, lineWidth: role == .ai ? 1 : 0))
                .clipShape(shape)
                .frame(maxWidth: 320, alignment: role == .user ? .trailing : .leading)
            if role == .ai { Spacer(minLength: 32) }
        }
        .frame(maxWidth: .infinity, alignment: role == .user ? .trailing : .leading)
    }

    @ViewBuilder
    private var background: some View {
        switch role {
        case .user:
            LinearGradient(colors: BovexaTheme.Gradients.teal, startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ai:
            tone == .error ? BovexaTheme.Colors.danger.opacity(0.10) : BovexaTheme.Colors.glassStrong
        }
    }

    private var foregroundColor: Color {
        switch role {
        case .user: return BovexaTheme.Colors.white
        case .ai: return tone == .error ? BovexaTheme.Colors.danger : BovexaTheme.Colors.inkSoft
        }
    }

    private var borderColor: Color {
        tone == .error ? BovexaTheme.Colors.danger : BovexaTheme.Colors.edge
    }
}

#Preview {
    ZStack {
        AppBackground()
        VStack(spacing: BovexaTheme.Space.sm) {
            ChatBubbleView(role: .user, text: "Morgen 15:00 tandarts")
            ChatBubbleView(role: .ai, text: "Welke dag bedoel je precies?")
            ChatBubbleView(role: .ai, text: "Er ging iets mis.", tone: .error)
        }
        .padding()
    }
}
