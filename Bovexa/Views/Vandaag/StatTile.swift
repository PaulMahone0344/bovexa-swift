import SwiftUI

struct StatTile: View {
    let value: String
    let label: String
    /// Optionele bijregel, bv. "1 afwezigheid" naast het aantal afspraken.
    var note: String?
    /// Icoonrondje boven het cijfer. Zonder icoon zijn de twee tegels alleen aan
    /// hun onderschrift uit elkaar te houden — je moet dan lezen om te zien of je
    /// naar afspraken of naar uren kijkt.
    var systemImage: String?
    var tint: Color = BovexaTheme.Colors.blue

    var body: some View {
        VStack(alignment: .leading, spacing: BovexaTheme.Space.xs) {
            if let systemImage {
                Circle()
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(tint)
                    }
                    .padding(.bottom, 2)
            }

            Text(value)
                .font(BovexaTheme.TypeStyle.statNumber)
                .foregroundStyle(BovexaTheme.Colors.ink)
            Text(label)
                .font(BovexaTheme.TypeStyle.statLabel)
                .foregroundStyle(BovexaTheme.Colors.inkSoft)
            if let note {
                Text(note)
                    .font(BovexaTheme.TypeStyle.caption)
                    .foregroundStyle(BovexaTheme.categoryColor(for: .afwezig))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    ZStack {
        AppBackground()
        GlassCard {
            HStack {
                StatTile(value: "3", label: "afspraken", systemImage: "calendar")
                StatTile(
                    value: "5,5 uur", label: "geplande uren",
                    systemImage: "clock", tint: BovexaTheme.Colors.categoryGreen
                )
            }
        }
        .padding()
    }
}
