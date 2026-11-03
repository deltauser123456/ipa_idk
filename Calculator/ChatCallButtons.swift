import SwiftUI
import FirebaseFirestore

struct ChatCallButtons: View {
    let chatID: String
    @StateObject private var call = CallSession()
    @State private var video = false
    @State private var muted = false

    var body: some View {
        HStack(spacing: 12) {
            Button("Voice call") {
                video = false
                Task { await call.connect(chatID: chatID, video: false) }
            }
            .disabled(call.isConnected)

            Button("Video call") {
                video = true
                Task { await call.connect(chatID: chatID, video: true) }
            }
            .disabled(call.isConnected)

            if call.isConnected {
                Button(muted ? "Unmute" : "Mute") {
                    muted.toggle()
                    Task { await call.setMuted(muted) }
                }
                Button("Hang up", role: .destructive) {
                    Task { await call.disconnect() }
                }
            }
        }
        .buttonStyle(.bordered)
        .alert("Call", isPresented: Binding(
            get: { call.errorMessage != nil },
            set: { if !$0 { call.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { call.errorMessage = nil }
        } message: {
            Text(call.errorMessage ?? "")
        }
    }
}
