import SwiftUI

/// Kaart "Deze week": drukte per dag ma-zo, niet tikbaar.
///
/// v3: staafjes met een hoogte per drukte in plaats van stippen die alleen in
/// doorzichtigheid verschilden — dat laatste las als zeven identieke puntjes.
struct WeekBusyCard: View {
    /// Aantal afspraken per dag, maandag eerst.
    let counts: [Int]

    private let labels = ["Ma", "Di", "Wo", "Do", "Vr", "Za", "Zo"]
    private let maxBarHeight: CGFloat = 34

    /// Maandag = 0. Calendar levert zondag = 1, dus omrekenen.
    private var todayIndex: Int {
        (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    }

    private var busiest: Int {
        max(counts.max() ?? 0, 1)
    }

    var body: some View {
        GlassCard(emphasis: .quiet) {
            VStack(alignment: .leading, spacing: BovexaTheme.Space.md) {
                Text("Deze week")
                    .font(BovexaTheme.TypeStyle.headline)
                    .foregroundStyle(BovexaTheme.Colors.ink)

                HStack(alignment: .bottom, spacing: BovexaTheme.Space.sm) {
                    ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                        let count = counts.indices.contains(index) ? counts[index] : 0
                        let isToday = index == todayIndex

                        VStack(spacing: BovexaTheme.Space.xs) {
                            Capsule()
                                .fill(barFill(count: count, isToday: isToday))
                                .frame(width: 8, height: barHeight(for: count))

                            Text(label)
                                .font(.system(.caption2, design: .rounded, weight: isToday ? .bold : .regular))
                                .foregroundStyle(isToday ? BovexaTheme.Colors.accent : BovexaTheme.Colors.muted)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: maxBarHeight + 20, alignment: .bottom)
            }
        }
    }

    private func barHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 6 }
        let ratio = CGFloat(count) / CGFloat(busiest)
        return 12 + (maxBarHeight - 12) * ratio
    }

    private func barFill(count: Int, isToday: Bool) -> Color {
        if count == 0 {
            return BovexaTheme.Colors.muted.opacity(isToday ? 0.35 : 0.18)
        }
        return isToday ? BovexaTheme.Colors.accent : BovexaTheme.Colors.teal.opacity(0.75)
    }
}

#Preview {
    ZStack {
        AppBackground()
        WeekBusyCard(counts: [2, 0, 1, 3, 1, 0, 0])
            .padding()
    }
}
