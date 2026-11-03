import SwiftUI
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import UIKit

private let db = Firestore.firestore()

struct RootView: View {
    @State private var user: User? = Auth.auth().currentUser
    @State private var authListener: AuthStateDidChangeListenerHandle?

    var body: some View {
        Group {
            if let user {
                ChatHomeView(user: user)
            } else {
                AuthView()
            }
        }
        .onAppear {
            if authListener == nil {
                authListener = Auth.auth().addStateDidChangeListener { _, user in
                    self.user = user
                }
            }
        }
        .onDisappear {
            if let authListener {
                Auth.auth().removeStateDidChangeListener(authListener)
                self.authListener = nil
            }
        }
    }
}

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isCreating = false
    @State private var busy = false
    @State private var error = ""

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 52)).foregroundStyle(.cyan)
                Text("Chat").font(.largeTitle.bold())
                Text(isCreating ? "Create your account" : "Sign in to continue")
                    .foregroundStyle(.white.opacity(0.65))
                VStack(spacing: 12) {
                    TextField("Email address", text: $email)
                        .textContentType(.emailAddress).keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    SecureField("Password (6+ characters)", text: $password)
                        .textContentType(isCreating ? .newPassword : .password)
                        .padding().background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }
                if !error.isEmpty {
                    Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                }
                Button(action: signInWithGoogle) {
                    HStack(spacing: 10) {
                        Image(systemName: "g.circle.fill").font(.title3)
                        Text("Continue with Google").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
                }
                .disabled(busy)
                HStack {
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                    Text("OR").font(.caption.bold()).foregroundStyle(.white.opacity(0.45))
                    Rectangle().fill(.white.opacity(0.2)).frame(height: 1)
                }
                Button(action: submit) {
                    HStack {
                        if busy { ProgressView().tint(.black) }
                        Text(isCreating ? "Create account" : "Sign in").bold()
                    }
                    .frame(maxWidth: .infinity).padding()
                    .background(.cyan, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.black)
                }
                .disabled(busy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.count < 6)
                Button(isCreating ? "Already have an account? Sign in" : "New here? Create an account") {
                    isCreating.toggle(); error = ""
                }
                .font(.footnote).foregroundStyle(.cyan)
            }
            .padding(26)
        }
    }


    private func signInWithGoogle() {
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let presenter = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            error = "Couldn't open Google sign-in. Please try again."
            return
        }
        busy = true
        error = ""
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, signInError in
            if let signInError {
                DispatchQueue.main.async { busy = false; error = signInError.localizedDescription }
                return
            }
            guard let result, let idToken = result.user.idToken?.tokenString else {
                DispatchQueue.main.async { busy = false; error = "Google sign-in didn't return an ID token." }
                return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
            Auth.auth().signIn(with: credential) { authResult, authError in
                DispatchQueue.main.async {
                    busy = false
                    if let authError { error = authError.localizedDescription; return }
                    guard let signedInUser = authResult?.user else { return }
                    db.collection("users").document(signedInUser.uid).setData([
                        "email": signedInUser.email ?? "",
                        "displayName": signedInUser.displayName ?? "Chat user",
                        "createdAt": FieldValue.serverTimestamp()
                    ], merge: true)
                }
            }
        }
    }

    private func submit() {
        busy = true; error = ""
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let completion: (AuthDataResult?, Error?) -> Void = { result, err in
            DispatchQueue.main.async {
                busy = false
                if let err { error = err.localizedDescription; return }
                if let user = result?.user {
                    db.collection("users").document(user.uid).setData([
                        "email": cleanEmail,
                        "displayName": user.displayName ?? cleanEmail,
                        "createdAt": FieldValue.serverTimestamp()
                    ], merge: true)
                }
            }
        }
        if isCreating {
            Auth.auth().createUser(withEmail: cleanEmail, password: password, completion: completion)
        } else {
            Auth.auth().signIn(withEmail: cleanEmail, password: password, completion: completion)
        }
    }
}

struct ChatSummary: Identifiable {
    let id: String
    let otherEmail: String
    let lastMessage: String
}

struct ChatHomeView: View {
    let user: User
    @State private var chats: [ChatSummary] = []
    @State private var listener: ListenerRegistration?
    @State private var showingNewChat = false
    @State private var recipientEmail = ""
    @State private var error = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MESSAGES").font(.caption.bold()).tracking(2).foregroundStyle(.cyan)
                            Text("Chats").font(.largeTitle.bold())
                        }
                        Spacer()
                        Button { showingNewChat = true } label: {
                            Image(systemName: "plus").font(.title3.bold())
                                .foregroundStyle(.black).frame(width: 44, height: 44)
                                .background(.cyan, in: Circle())
                        }
                    }.padding()
                    if chats.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 44)).foregroundStyle(.cyan)
                            Text("No chats yet").font(.title2.bold())
                            Text("Start a chat using someone's account email.")
                                .font(.subheadline).foregroundStyle(.white.opacity(0.6))
                            Button("New chat") { showingNewChat = true }
                                .padding(.horizontal, 20).padding(.vertical, 11)
                                .background(.cyan, in: Capsule()).foregroundStyle(.black)
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 9) {
                                ForEach(chats) { chat in
                                    NavigationLink {
                                        LiveConversationView(chat: chat, myUID: user.uid)
                                    } label: {
                                        HStack(spacing: 14) {
                                            Image(systemName: "person.fill")
                                                .font(.title2).foregroundStyle(.cyan)
                                                .frame(width: 52, height: 52)
                                                .background(.cyan.opacity(0.15), in: Circle())
                                            VStack(alignment: .leading, spacing: 5) {
                                                Text(chat.otherEmail).font(.headline)
                                                Text(chat.lastMessage).font(.subheadline)
                                                    .foregroundStyle(.white.opacity(0.55)).lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right").font(.caption)
                                                .foregroundStyle(.white.opacity(0.3))
                                        }
                                        .padding(13).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 17))
                                    }.buttonStyle(.plain)
                                }
                            }.padding(.horizontal, 14)
                        }
                    }
                    HStack {
                        Text(user.email ?? "Signed in").font(.caption).foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Button("Sign out") { try? Auth.auth().signOut() }
                            .font(.caption.bold()).foregroundStyle(.cyan)
                    }.padding()
                }.foregroundStyle(.white)
            }
            .toolbar(.hidden, for: .navigationBar)
            .alert("New chat", isPresented: $showingNewChat) {
                TextField("Their account email", text: $recipientEmail)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                Button("Cancel", role: .cancel) { recipientEmail = "" }
                Button("Create", action: createChat)
            } message: {
                Text("Enter the email address they used to create their Chat account.")
            }
            .alert("Couldn't create chat", isPresented: Binding(get: { !error.isEmpty }, set: { if !$0 { error = "" } })) {
                Button("OK", role: .cancel) { error = "" }
            } message: { Text(error) }
        }
        .tint(.cyan)
        .onAppear(perform: listen)
        .onDisappear { listener?.remove(); listener = nil }
    }

    private func listen() {
        listener?.remove()
        listener = db.collection("chats")
            .whereField("participantUIDs", arrayContains: user.uid)
            .addSnapshotListener { snapshot, err in
                guard let docs = snapshot?.documents, err == nil else { return }
                let values = docs.map { doc -> ChatSummary in
                    let data = doc.data()
                    let ids = data["participantUIDs"] as? [String] ?? []
                    let emails = data["participantEmails"] as? [String] ?? []
                    let otherIndex = ids.firstIndex(where: { $0 != user.uid }) ?? 0
                    let otherEmail = otherIndex < emails.count ? emails[otherIndex] : "Chat"
                    return ChatSummary(id: doc.documentID, otherEmail: otherEmail,
                                       lastMessage: data["lastMessage"] as? String ?? "Start chatting")
                }
                DispatchQueue.main.async { chats = values }
            }
    }

    private func createChat() {
        let email = recipientEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        recipientEmail = ""
        guard !email.isEmpty, email != (user.email ?? "").lowercased() else {
            error = "Enter a different account email."; return
        }
        db.collection("users").whereField("email", isEqualTo: email).limit(to: 1).getDocuments { snapshot, err in
            if let err { error = err.localizedDescription; return }
            guard let recipient = snapshot?.documents.first else {
                error = "No Chat account was found for that email. Ask them to create an account first."; return
            }
            let otherUID = recipient.documentID
            let participants = [(user.uid, user.email ?? ""), (otherUID, email)].sorted { $0.0 < $1.0 }
            let ids = participants.map { $0.0 }
            let emails = participants.map { $0.1 }
            db.collection("chats").whereField("participantUIDs", isEqualTo: ids).limit(to: 1).getDocuments { existing, findError in
                if let findError { error = findError.localizedDescription; return }
                if existing?.documents.first != nil { return }
                db.collection("chats").addDocument(data: [
                    "participantUIDs": ids,
                    "participantEmails": emails,
                    "lastMessage": "Say hello!",
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ]) { createError in
                    if let createError { error = createError.localizedDescription }
                }
            }
        }
    }
}

struct LiveMessage: Identifiable {
    let id: String
    let text: String
    let senderUID: String
}

struct LiveConversationView: View {
    let chat: ChatSummary
    let myUID: String
    @State private var messages: [LiveMessage] = []
    @State private var draft = ""
    @State private var listener: ListenerRegistration?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            HStack {
                                if message.senderUID == myUID { Spacer(minLength: 55) }
                                Text(message.text).padding(.horizontal, 15).padding(.vertical, 11)
                                    .foregroundStyle(message.senderUID == myUID ? .black : .white)
                                    .background(message.senderUID == myUID ? Color.cyan : Color.white.opacity(0.11),
                                                in: RoundedRectangle(cornerRadius: 18))
                                if message.senderUID != myUID { Spacer(minLength: 55) }
                            }.id(message.id)
                        }
                    }.padding()
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            HStack(spacing: 10) {
                TextField("Message...", text: $draft, axis: .vertical)
                    .lineLimit(1...4).padding(12)
                    .background(.white.opacity(0.08), in: Capsule()).foregroundStyle(.white)
                Button(action: send) {
                    Image(systemName: "arrow.up").bold().foregroundStyle(.black)
                        .frame(width: 42, height: 42).background(.cyan, in: Circle())
                }.disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }.padding().background(.black)
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle(chat.otherEmail).navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: listen)
        .onDisappear { listener?.remove(); listener = nil }
    }

    private func listen() {
        listener = db.collection("chats").document(chat.id).collection("messages")
            .order(by: "createdAt")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let newMessages = docs.map { doc in
                    LiveMessage(id: doc.documentID, text: doc.data()["text"] as? String ?? "",
                                senderUID: doc.data()["senderUID"] as? String ?? "")
                }
                DispatchQueue.main.async { messages = newMessages }
            }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""
        let chatRef = db.collection("chats").document(chat.id)
        chatRef.collection("messages").addDocument(data: [
            "text": text,
            "senderUID": myUID,
            "createdAt": FieldValue.serverTimestamp()
        ]) { error in
            if error == nil {
                chatRef.updateData(["lastMessage": text, "updatedAt": FieldValue.serverTimestamp()])
            }
        }
    }
}
