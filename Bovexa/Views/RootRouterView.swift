import SwiftUI

/// Root-router: spinner tijdens de stille authRefresh-beslissing, dan pas login of tabs.
struct RootRouterView: View {
    @StateObject private var authStore = AuthStore()
    @StateObject private var joinCoordinator = JoinCoordinator()
    @StateObject private var tabRouter = TabRouter()
    @Environment(\.scenePhase) private var scenePhase

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
                    .readableWidth()
            case .loggedIn:
                if authStore.justRegistered {
                    OnboardingView()
                        .readableWidth()
                } else {
                    RootTabView()
                }
            }
        }
        .environmentObject(authStore)
        .environmentObject(joinCoordinator)
        .environmentObject(tabRouter)
        .task {
            await authStore.bootstrap()
        }
        .onOpenURL { url in
            guard let code = JoinDeepLink.code(from: url) else { return }
            handle(code: code)
        }
        // Terugkomen uit de achtergrond. De app 's avonds open laten en 's ochtends
        // openen liet Vandaag de afspraken van gisteren tonen tot je van tab
        // wisselde, en het token werd alleen bij app-start ververst.
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, case .loggedIn = authStore.phase else { return }
            authStore.markForeground()
            Task { await authStore.refreshCurrentUser() }
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
