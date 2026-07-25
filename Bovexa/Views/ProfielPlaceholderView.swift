import SwiftUI

/// Profiel-placeholder met de tijdelijke uitlog-knop (plan plak 2: anders kom je
/// nooit meer uit een account tot het echte Profiel-scherm er is). Plak 5 voegt de
/// rij "Beschikbaarheid doorgeven" toe — de rest van Profiel blijft placeholder tot
/// milestone 6.
struct ProfielPlaceholderView: View {
    @EnvironmentObject private var authStore: AuthStore
    @State private var showAfwezig = false

    private var currentUser: AgendaUser? {
        if case .loggedIn(let user) = authStore.phase { return user }
        return nil
    }

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

                Button {
                    Haptics.selection()
                    showAfwezig = true
                } label: {
                    HStack {
                        Text("Beschikbaarheid doorgeven")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                }
                .font(.system(size: BovexaTheme.TypeScale.body, weight: .semibold))
                .foregroundStyle(BovexaTheme.Colors.ink)
                .padding(.vertical, BovexaTheme.Space.sm)
                .padding(.horizontal, BovexaTheme.Space.xl)
                .background(BovexaTheme.Colors.glassSoft)
                .clipShape(RoundedRectangle(cornerRadius: BovexaTheme.Radius.pill, style: .continuous))

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
        .sheet(isPresented: $showAfwezig) {
            if let user = currentUser {
                AfwezigView(userId: user.id, org: user.defaultOrg, token: authStore.token ?? "")
            }
        }
    }
}

#Preview {
    ProfielPlaceholderView().environmentObject(AuthStore())
}
