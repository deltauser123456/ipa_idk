import SwiftUI

@main
struct ChatApp: App {
    var body: some Scene {
        WindowGroup {
            ChatHomeView()
                .preferredColorScheme(.dark)
        }
    }
}
