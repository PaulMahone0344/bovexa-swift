import SwiftUI

/// Root-router: spinner tijdens de stille authRefresh-beslissing, dan pas login of tabs.
struct RootRouterView: View {
    @StateObject private var authStore = AuthStore()
    @StateObject private var joinCoordinator = JoinCoordinator()
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var badgeStore = BadgeStore()
    @ObservedObject private var pushInbox = PushTokenInbox.shared
    @Environment(\.scenePhase) private var scenePhase

    private let pushRegistration = PushRegistrationService()

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
        .environmentObject(badgeStore)
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
            // Pushmeldingen: bij het inloggen om een device-token vragen. Dit toont
            // géén systeemprompt (dat doet alleen UNUserNotificationCenter), dus
            // niemand krijgt hier een ongevraagde vraag. Het token komt asynchroon
            // binnen via de AppDelegate en wordt hieronder weggeschreven.
            if case .loggedIn = phase {
                pushRegistration.register()
                storePushTokenIfPossible()
            } else {
                pushRegistration.forgetLocalToken()
            }

            // Valkuil G, uitkomst 1: code kwam binnen terwijl nog niet ingelogd —
            // na een geslaagde login alsnog verwerken. Net geregistreerd? Dan
            // handelt OnboardingView de voorgevulde code zelf af (valkuil B).
            guard case .loggedIn = phase, !authStore.justRegistered, let code = joinCoordinator.pendingCode else { return }
            joinCoordinator.pendingCode = nil
            handle(code: code)
        }
        // Het token kan ook ná de login binnenkomen; dan is dit de kant die vuurt.
        .onChange(of: pushInbox.hexToken) { _, _ in
            storePushTokenIfPossible()
        }
    }

    /// Schrijft het APNs-token weg zodra gebruiker én token er allebei zijn. De
    /// volgorde waarin ze binnenkomen ligt niet vast, dus beide kanten roepen dit aan.
    private func storePushTokenIfPossible() {
        guard case .loggedIn(let user) = authStore.phase,
              let token = authStore.token,
              let hexToken = pushInbox.hexToken else { return }
        Task {
            await pushRegistration.store(hexToken: hexToken, userId: user.id, token: token)
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
