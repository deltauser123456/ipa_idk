import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct ChatApp: App {
    init() { FirebaseApp.configure() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                .onOpenURL { url in GIDSignIn.sharedInstance.handle(url) }
        }
    }
}
