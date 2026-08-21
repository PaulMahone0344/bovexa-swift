import SwiftUI
import UIKit

/// APNs praat met de UIApplicationDelegate, niet met SwiftUI. Deze adaptor is het
/// enige stuk UIKit in de app: hij vangt het device-token op en legt het in
/// PushTokenInbox, waar RootRouterView het oppakt zodra er een gebruiker is.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            PushTokenInbox.shared.deliver(deviceToken: deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        Task { @MainActor in
            PushTokenInbox.shared.deliverFailure()
        }
    }
}

@main
struct BovexaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            RootRouterView()
                .preferredColorScheme(.light)
        }
    }
}
