import SwiftUI

/// Root-router: spinner tijdens de stille authRefresh-beslissing, dan pas login of tabs.
struct RootRouterView: View {
    @StateObject private var authStore = AuthStore()
    @StateObject private var joinCoordinator = JoinCoordinator()

    var body: some View {
        Group {
            switch authStore.phase {
            case .deciding:
                ZStack {
                    AppBackground()
                    ProgressView()
                        .tint(BovexaTheme.Colors.blue)
                }
            case .loggedOut:
                LoginView()
            case .loggedIn:
                if authStore.justRegistered {
                    OnboardingView()
                } else {
                    RootTabView()
                }
            }
        }
        .environmentObject(authStore)
        .environmentObject(joinCoordinator)
        .task {
            await authStore.bootstrap()
        }
        .onOpenURL { url in
            guard let code = JoinDeepLink.code(from: url) else { return }
            handle(code: code)
        }
        .onChange(of: authStore.phase) { _, phase in
            // Valkuil G, uitkomst 1: code kwam binnen terwijl nog niet ingelogd —
            // na een geslaagde login alsnog verwerken. Net geregistreerd? Dan
            // handelt OnboardingView de voorgevulde code zelf af (valkuil B).
            guard case .loggedIn = phase, !authStore.justRegistered, let code = joinCoordinator.pendingCode else { return }
            joinCoordinator.pendingCode = nil
            handle(code: code)
        }
    }

    private func handle(code: String) {
        guard case .loggedIn(let user) = authStore.phase else {
            joinCoordinator.pendingCode = code
            return
        }
        Task {
            await joinCoordinator.join(code: code, alreadyHasCompany: user.defaultOrg != nil, token: authStore.token ?? "")
        }
    }
}

#Preview {
    RootRouterView()
}
