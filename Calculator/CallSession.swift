import Foundation
import FirebaseAuth
import LiveKit

@MainActor
final class CallSession: ObservableObject {
    @Published private(set) var isConnected = false
    @Published var errorMessage: String?

    private let room = Room()

    func connect(chatID: String, video: Bool) async {
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Please sign in before calling."
            return
        }

        do {
            let idToken = try await user.getIDToken()
            let endpoint = URL(string: "https://chat-call-server.onrender.com/token")!
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: [
                "roomName": "chat_\(chatID)"
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw NSError(domain: "CallSession", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Call server rejected the request."])
            }
            let payload = try JSONDecoder().decode(TokenResponse.self, from: data)
            try await room.connect(url: payload.serverUrl, token: payload.token)
            try await room.localParticipant.setMicrophone(enabled: true)
            if video {
                try await room.localParticipant.setCamera(enabled: true)
            }
            isConnected = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setMuted(_ muted: Bool) async {
        do {
            try await room.localParticipant.setMicrophone(enabled: !muted)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func setCameraEnabled(_ enabled: Bool) async {
        do {
            try await room.localParticipant.setCamera(enabled: enabled)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func disconnect() async {
        await room.disconnect()
        isConnected = false
    }
}

private struct TokenResponse: Decodable {
    let token: String
    let serverUrl: String
}
