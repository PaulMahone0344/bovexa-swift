import SwiftUI

/// Profiel-placeholder met de tijdelijke uitlog-knop (plan plak 2: anders kom je
/// nooit meer uit een account tot het echte Profiel-scherm er is).
struct ProfielPlaceholderView: View {
    @EnvironmentObject private var authStore: AuthStore

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: BovexaTheme.Space.lg) {
                GlassCard {
                    VStack(spacing: BovexaTheme.Space.sm) {
                        Text("Profiel")
                            .font(.system(size: BovexaTheme.TypeScale.h2, weight: .semibold))
                            .foregroundStyle(BovexaTheme.Colors.ink)
                        Text("Komt binnenkort")
                            .font(.system(size: BovexaTheme.TypeScale.body))
                            .foregroundStyle(BovexaTheme.Colors.muted)
                    }
                }

                Button("Uitloggen") {
                    authStore.signOut()
                }
                .font(.system(size: BovexaTheme.TypeScale.body, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.danger)
                .padding(.vertical, BovexaTheme.Space.sm)
                .padding(.horizontal, BovexaTheme.Space.xl)
                .background(BovexaTheme.Colors.glassSoft)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.pill, style: .continuous))
            }
            .padding(BovexaTheme.Space.xl)
        }
    }
}

#Preview {
    ProfielPlaceholderView().environmentObject(AuthStore())
}
