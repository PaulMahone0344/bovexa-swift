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
                        .tint(BovexaTheme.Colors.teal)
                }
            case .loggedOut:
                LoginView()
            case .loggedIn:
                RootTabView()
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
            // na een geslaagde login/registratie alsnog verwerken.
            guard case .loggedIn = phase, let code = joinCoordinator.pendingCode else { return }
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
