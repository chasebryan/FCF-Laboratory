import SwiftUI

struct AIWorkspacePanel: View {
    @ObservedObject var controller: AIWorkspaceController
    @ObservedObject private var auth: OpenAIAuthService
    @ObservedObject private var policy: AIContextPolicy
    let contextProvider: @MainActor () -> AIWorkspaceContextSnapshot

    @State private var apiKey = ""
    @State private var prompt = ""

    init(
        controller: AIWorkspaceController,
        contextProvider: @escaping @MainActor () -> AIWorkspaceContextSnapshot
    ) {
        self.controller = controller
        self._auth = ObservedObject(wrappedValue: controller.auth)
        self._policy = ObservedObject(wrappedValue: controller.policy)
        self.contextProvider = contextProvider
    }

    var body: some View {
        VStack(spacing: 0) {
            authAndPermissions
            Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1)
            conversation
            Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1)
            composer
        }
    }

    private var authAndPermissions: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                statusLabel
                Spacer()
                TextField(
                    "Model",
                    text: Binding(
                        get: { auth.model },
                        set: { auth.model = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10, design: .monospaced))
                .frame(width: 120)
            }

            if case .unconfigured = auth.status {
                HStack(spacing: 8) {
                    SecureField("OpenAI API key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10.5))
                    Button("Store in Keychain") {
                        auth.storeAPIKey(apiKey)
                        apiKey = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(apiKey.isEmpty)
                }
            }

            HStack(spacing: 14) {
                permissionToggle("Document", keyPath: \AIContextPolicy.activeDocument)
                permissionToggle("Notebook", keyPath: \AIContextPolicy.activeNotebook)
                permissionToggle("Terminal", keyPath: \AIContextPolicy.terminalTranscript)
                permissionToggle("Project files", keyPath: \AIContextPolicy.projectFiles)
                permissionToggle("Git diff", keyPath: \AIContextPolicy.gitDiff)
                Spacer()
                Button("Revoke All") { policy.revokeAll() }
                    .buttonStyle(.plain)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundStyle(.tertiary)
            }

            Text("Only checked workspace scopes are included or exposed as tools. OpenAI API credentials stay in the environment or macOS Keychain.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch auth.status {
        case .unconfigured:
            Label("OpenAI not configured", systemImage: "sparkles")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        case .configured(let source):
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("OpenAI")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(source.rawValue)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenAI credential error")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(message)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func permissionToggle(
        _ title: String,
        keyPath: ReferenceWritableKeyPath<AIContextPolicy, Bool>
    ) -> some View {
        Toggle(
            title,
            isOn: Binding(
                get: { policy[keyPath: keyPath] },
                set: { policy[keyPath: keyPath] = $0 }
            )
        )
        .toggleStyle(.checkbox)
        .font(.system(size: 9))
        .fixedSize()
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if let conversation = controller.conversation, !conversation.messages.isEmpty {
                        ForEach(conversation.messages) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role == .user ? "YOU" : "OPENAI")
                                    .font(.system(size: 8.5, weight: .semibold))
                                    .tracking(0.7)
                                    .foregroundStyle(.tertiary)
                                Text(message.text)
                                    .font(.system(size: 11))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .id(message.id)
                        }
                    } else {
                        Text("Ask about the project, reason through a notebook, inspect a granted diff, or work without sharing any workspace context at all.")
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, minHeight: 180, alignment: .center)
                    }

                    if controller.isSending {
                        HStack(spacing: 7) {
                            ProgressView().controlSize(.mini)
                            Text("Thinking")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let error = controller.errorMessage {
                        Text(error)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
            }
            .frame(minHeight: 245)
            .onChange(of: controller.conversation?.messages.count ?? 0) { _, _ in
                if let id = controller.conversation?.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 9) {
            TextField("Ask OpenAI", text: $prompt, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 11.5))
                .lineLimit(1...5)
                .onSubmit { send() }

            Button {
                controller.newConversation()
            } label: {
                Image(systemName: "plus.bubble")
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("New conversation")

            Button { send() } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || controller.isSending)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func send() {
        let value = prompt
        prompt = ""
        controller.send(value, context: contextProvider())
    }
}
