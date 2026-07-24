import SwiftUI

/// Tijdelijke navigatiedoel vanuit Vandaag/Agenda tot het echte read-only
/// afspraak-detail er is (plak 6).
struct EventDetailPlaceholderView: View {
    let eventId: String

    var body: some View {
        ZStack {
            AppBackground()
            GlassCard {
                VStack(spacing: BovexaTheme.Space.sm) {
                    Text("Afspraak-detail")
                        .font(.system(size: BovexaTheme.TypeScale.h2, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Text("Komt binnenkort")
                        .font(.system(size: BovexaTheme.TypeScale.body))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
            .padding(BovexaTheme.Space.xl)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        EventDetailPlaceholderView(eventId: "ev1")
    }
}
