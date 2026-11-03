import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isMine: Bool
    let time = Date()
}

struct ChatConversation: Identifiable {
    let id = UUID()
    var name: String
    var members: [String]
    var isGroup: Bool
    var messages: [ChatMessage]
    var lastMessage: String { messages.last?.text ?? "Start a conversation" }
}

struct ChatHomeView: View {
    @State private var chats: [ChatConversation] = [
        ChatConversation(name: "Alex", members: ["Alex"], isGroup: false,
                         messages: [ChatMessage(text: "Hey! What's up?", isMine: false)]),
        ChatConversation(name: "Weekend crew", members: ["Alex", "Sam", "Jordan"], isGroup: true,
                         messages: [ChatMessage(text: "Anyone free this weekend?", isMine: false)])
    ]
    @State private var showingNewChat = false
    @State private var showingNewGroup = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MESSAGES")
                                .font(.caption.weight(.bold))
                                .tracking(2)
                                .foregroundStyle(.cyan)
                            Text("Chats")
                                .font(.largeTitle.bold())
                        }
                        Spacer()
                        Button { showingNewChat = true } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.title3.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.10), in: Circle())
                        }
                        .accessibilityLabel("New chat")
                        Menu {
                            Button { showingNewChat = true } label: {
                                Label("New solo chat", systemImage: "person")
                            }
                            Button { showingNewGroup = true } label: {
                                Label("New group chat", systemImage: "person.3")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3.bold())
                                .frame(width: 44, height: 44)
                                .background(Color.cyan, in: Circle())
                                .foregroundStyle(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 22)

                    if chats.isEmpty {
                        ContentUnavailableView("No chats yet", systemImage: "bubble.left.and.bubble.right",
                                               description: Text("Start a solo chat or create a group."))
                            .foregroundStyle(.white)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(chats) { chat in
                                    NavigationLink {
                                        ConversationView(chat: chat) { updated in
                                            if let index = chats.firstIndex(where: { $0.id == updated.id }) {
                                                chats[index] = updated
                                            }
                                        }
                                    } label: {
                                        ChatRow(chat: chat)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 14)
                        }
                    }
                    Spacer(minLength: 0)
                    HStack {
                        Label("Chats", systemImage: "bubble.left.and.bubble.right.fill")
                            .foregroundStyle(.cyan)
                        Spacer()
                        Label("Calls", systemImage: "phone")
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Label("You", systemImage: "person.crop.circle")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 34)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.04))
                }
            }
            .foregroundStyle(.white)
            .sheet(isPresented: $showingNewChat) {
                NewChatSheet(title: "New solo chat", group: false) { name in
                    chats.insert(ChatConversation(name: name, members: [name], isGroup: false, messages: []), at: 0)
                }
            }
            .sheet(isPresented: $showingNewGroup) {
                NewChatSheet(title: "Create group", group: true) { name in
                    chats.insert(ChatConversation(name: name, members: ["You", "Alex", "Sam"], isGroup: true, messages: []), at: 0)
                }
            }
        }
        .tint(.cyan)
    }
}

struct ChatRow: View {
    let chat: ChatConversation
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(chat.isGroup ? Color.purple.opacity(0.25) : Color.cyan.opacity(0.18))
                Image(systemName: chat.isGroup ? "person.3.fill" : "person.fill")
                    .font(.title2)
                    .foregroundStyle(chat.isGroup ? .purple : .cyan)
            }
            .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(chat.name).font(.headline)
                    Spacer()
                    Text(chat.messages.isEmpty ? "" : "now")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
                Text(chat.lastMessage)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.25))
        }
        .padding(13)
        .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 18))
    }
}

struct ConversationView: View {
    @State var chat: ChatConversation
    var onUpdate: (ChatConversation) -> Void
    @State private var draft = ""
    @State private var showingCall = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chat.name).font(.headline)
                    Text(chat.isGroup ? "\(chat.members.count) members" : "Direct message")
                        .font(.caption).foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button { showingCall = true } label: {
                    Image(systemName: "phone.fill")
                        .font(.title3)
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(.cyan, in: Circle())
                }
                .accessibilityLabel("Call")
            }
            .padding()
            .background(Color.white.opacity(0.04))

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(chat.messages) { message in
                        HStack {
                            if message.isMine { Spacer(minLength: 55) }
                            Text(message.text)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 11)
                                .foregroundStyle(message.isMine ? .black : .white)
                                .background(message.isMine ? Color.cyan : Color.white.opacity(0.10),
                                            in: RoundedRectangle(cornerRadius: 18))
                            if !message.isMine { Spacer(minLength: 55) }
                        }
                    }
                }
                .padding()
            }
            HStack(spacing: 10) {
                TextField("Message...", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .foregroundStyle(.white)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .foregroundStyle(.black)
                        .frame(width: 42, height: 42)
                        .background(.cyan, in: Circle())
                }
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color.black)
        }
        .background(Color(red: 0.04, green: 0.05, blue: 0.08).ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showingCall) {
            CallScreen(name: chat.name, group: chat.isGroup)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        chat.messages.append(ChatMessage(text: text, isMine: true))
        draft = ""
        onUpdate(chat)
    }
}

struct NewChatSheet: View {
    let title: String
    let group: Bool
    var onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            Form {
                Section(group ? "Group details" : "Contact") {
                    TextField(group ? "Group name" : "Person's name", text: $name)
                }
                if group {
                    Section("Members") {
                        Label("You", systemImage: "person.fill")
                        Label("Alex (demo contact)", systemImage: "person")
                        Label("Sam (demo contact)", systemImage: "person")
                    }
                }
                Section {
                    Text(group ? "This creates a sample group on this device." : "This creates a sample conversation on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !value.isEmpty else { return }
                        onCreate(value)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct CallScreen: View {
    let name: String
    let group: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.05, green: 0.12, blue: 0.20), .black],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: group ? "person.3.fill" : "person.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.cyan)
                    .frame(width: 132, height: 132)
                    .background(.white.opacity(0.08), in: Circle())
                Text(name).font(.largeTitle.bold())
                Text("Call preview")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                Text("Calling isn't connected yet")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(.red, in: Circle())
                }
                Text("End")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.bottom, 34)
            }
            .foregroundStyle(.white)
        }
    }
}
