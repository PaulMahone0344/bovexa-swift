import SwiftUI

/// Placeholder voor tabs die in latere milestones gebouwd worden.
struct ComingSoonView: View {
    let title: String

    var body: some View {
        ZStack {
            AppBackground()
            GlassCard {
                VStack(spacing: BovexaTheme.Space.sm) {
                    Text(title)
                        .font(.system(size: BovexaTheme.TypeScale.h2, weight: .semibold))
                        .foregroundStyle(BovexaTheme.Colors.ink)
                    Text("Komt binnenkort")
                        .font(.system(size: BovexaTheme.TypeScale.body))
                        .foregroundStyle(BovexaTheme.Colors.muted)
                }
            }
            .padding(BovexaTheme.Space.xl)
        }
    }
}

#Preview {
    ComingSoonView(title: "Dagtaken")
}
