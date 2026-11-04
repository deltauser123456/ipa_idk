import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ChatCallButtons: View {
    let chatID: String
    @StateObject private var call = CallSession()
    @State private var muted = false
    @State private var otherUID: String?
    @State private var incomingCallID: String?
    @State private var incomingType = "audio"
    @State private var activeCallID: String?
    @State private var status = ""
    @State private var busy = false
    @State private var chatListener: ListenerRegistration?
    @State private var callsListener: ListenerRegistration?

    private var calls: CollectionReference {
        Firestore.firestore().collection("chats").document(chatID).collection("calls")
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button("Voice call") { startCall(video: false) }
                    .disabled(call.isConnected || busy)
                Button("Video call") { startCall(video: true) }
                    .disabled(call.isConnected || busy)
            }
            .buttonStyle(.bordered)

            if let incomingCallID, !call.isConnected {
                Text("Incoming \(incomingType == "video" ? "video" : "voice") call")
                    .font(.subheadline.bold())
                HStack {
                    Button("Accept") { acceptCall(id: incomingCallID) }
                        .disabled(busy)
                        .buttonStyle(.borderedProminent)
                    Button("Decline", role: .destructive) { declineCall(id: incomingCallID) }
                        .disabled(busy)
                        .buttonStyle(.bordered)
                }
            }

            if call.isConnected {
                HStack {
                    Button(muted ? "Unmute" : "Mute") {
                        muted.toggle()
                        Task { await call.setMuted(muted) }
                    }
                    Button("Hang up", role: .destructive) { hangUp() }
                }
                .buttonStyle(.bordered)
            }

            if !status.isEmpty {
                Text(status).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear(perform: listenForCalls)
        .onDisappear {
            chatListener?.remove()
            callsListener?.remove()
            chatListener = nil
            callsListener = nil
        }
        .alert("Call", isPresented: Binding(
            get: { call.errorMessage != nil },
            set: { if !$0 { call.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { call.errorMessage = nil }
        } message: {
            Text(call.errorMessage ?? "")
        }
    }

    private func listenForCalls() {
        let uid = Auth.auth().currentUser?.uid
        guard let uid else { return }
        chatListener?.remove()
        chatListener = Firestore.firestore().collection("chats").document(chatID)
            .addSnapshotListener { snapshot, _ in
                let ids = snapshot?.data()?["participantUIDs"] as? [String] ?? []
                otherUID = ids.first(where: { $0 != uid })
            }
        callsListener?.remove()
        callsListener = calls.whereField("calleeUID", isEqualTo: uid)
            .whereField("status", isEqualTo: "ringing")
            .addSnapshotListener { snapshot, _ in
                let doc = snapshot?.documents.first
                incomingCallID = doc?.documentID
                incomingType = doc?.data()["type"] as? String ?? "audio"
            }
    }

    private func startCall(video: Bool) {
        guard let uid = Auth.auth().currentUser?.uid, let otherUID, !busy else {
            status = "Chat is still loading. Try again."
            return
        }
        busy = true
        let ref = calls.document()
        ref.setData([
            "callerUID": uid,
            "calleeUID": otherUID,
            "status": "ringing",
            "type": video ? "video" : "audio",
            "roomName": "chat_\(chatID)",
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error {
                status = error.localizedDescription
                busy = false
            } else {
                activeCallID = ref.documentID
                connect(video: video)
            }
        }
    }

    private func acceptCall(id: String) {
        let useVideo = incomingType == "video"
        busy = true
        calls.document(id).updateData([
            "status": "accepted",
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error {
                status = error.localizedDescription
                busy = false
            } else {
                activeCallID = id
                connect(video: useVideo)
            }
        }
    }

    private func declineCall(id: String) {
        calls.document(id).updateData([
            "status": "declined",
            "updatedAt": FieldValue.serverTimestamp()
        ]) { error in
            if let error { status = error.localizedDescription }
            else { status = "Call declined" }
        }
    }

    private func connect(video: Bool) {
        Task {
            await call.connect(chatID: chatID, video: video)
            busy = false
            if call.isConnected { status = "Connected" }
            else if let id = activeCallID {
                calls.document(id).updateData([
                    "status": "ended",
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
        }
    }

    private func hangUp() {
        Task {
            await call.disconnect()
            if let id = activeCallID {
                calls.document(id).updateData([
                    "status": "ended",
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            }
            activeCallID = nil
            status = "Call ended"
        }
    }
}
