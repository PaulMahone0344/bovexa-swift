import SwiftUI

/// Root-router: spinner tijdens de stille authRefresh-beslissing, dan pas login of tabs.
struct RootRouterView: View {
    @StateObject private var authStore = AuthStore()

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
        .task {
            await authStore.bootstrap()
        }
    }
}

#Preview {
    RootRouterView()
}
