import SwiftUI

/// Kaart "Deze week": 7 drukte-stippen ma-zo, niet tikbaar.
struct WeekBusyCard: View {
    /// Aantal afspraken per dag, maandag eerst.
    let counts: [Int]

    private let labels = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.sm) {
                Text("Deze week")
                    .font(.system(size: BovexaTheme.TypeScale.title, weight: .semibold))
                    .foregroundStyle(BovexaTheme.Colors.ink)

                HStack(spacing: BovexaTheme.Space.md) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                        VStack(spacing: BovexaTheme.Space.xs) {
                            Circle()
                                .fill(BovexaTheme.Colors.teal.opacity(dotOpacity(for: counts[safe: index] ?? 0)))
                                .frame(width: 10, height: 10)
                            Text(label)
                                .font(.system(size: BovexaTheme.TypeScale.tiny))
                                .foregroundStyle(BovexaTheme.Colors.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func dotOpacity(for count: Int) -> Double {
        switch count {
        case 0: return 0.18
        case 1: return 0.45
        case 2: return 0.7
        default: return 1.0
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ZStack {
        AppBackground()
        WeekBusyCard(counts: [2, 0, 1, 3, 1, 0, 0])
            .padding()
    }
}
