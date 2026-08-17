import CryptoKit
import Foundation

struct AIConversationMessage: Codable, Identifiable, Hashable, Sendable {
    enum Role: String, Codable, Sendable { case user, assistant }
    let id: UUID
    let role: Role
    let text: String
    let createdAt: Date
    let providerResponseID: String?
}

struct AIConversation: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var projectPath: String
    var messages: [AIConversationMessage]
    var updatedAt: Date

    static func fresh(projectURL: URL) -> AIConversation {
        AIConversation(id: UUID(), projectPath: projectURL.standardizedFileURL.path, messages: [], updatedAt: Date())
    }
}

@MainActor
final class AIWorkspaceController: ObservableObject, @unchecked Sendable, NotebookAIExecuting {
    let auth = OpenAIAuthService()
    let policy = AIContextPolicy()

    @Published private(set) var conversation: AIConversation?
    @Published private(set) var isSending = false
    @Published private(set) var errorMessage: String?

    private var projectURL: URL?

    func openProject(_ url: URL) {
        projectURL = url.standardizedFileURL
        errorMessage = nil
        Task {
            conversation = await AIConversationStore.load(projectURL: url) ?? .fresh(projectURL: url)
        }
    }

    func newConversation() {
        guard let projectURL else { return }
        conversation = .fresh(projectURL: projectURL)
        Task { await persist() }
    }

    func send(_ prompt: String, context: AIWorkspaceContextSnapshot) {
        guard let projectURL else { return }
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }
        isSending = true
        errorMessage = nil

        Task {
            do {
                guard let key = try auth.resolvedAPIKey(), !key.isEmpty else { throw AIWorkspaceError.notConfigured }
                var current = conversation ?? .fresh(projectURL: projectURL)
                current.messages.append(AIConversationMessage(id: UUID(), role: .user, text: trimmed, createdAt: Date(), providerResponseID: nil))
                current.updatedAt = Date()
                conversation = current
                await persist()

                let grants = AIContextGrantSnapshot(projectFiles: policy.projectFiles, gitDiff: policy.gitDiff)
                let transcript = boundedTranscript(current.messages.dropLast())
                let result = try await OpenAIResponsesClient(apiKey: key, model: auth.model).respond(
                    prompt: trimmed,
                    projectURL: projectURL,
                    context: context,
                    grants: grants,
                    conversationTranscript: transcript
                )

                current.messages.append(AIConversationMessage(id: UUID(), role: .assistant, text: result.text, createdAt: Date(), providerResponseID: result.id))
                current.updatedAt = Date()
                conversation = current
                await persist()
                isSending = false
            } catch {
                errorMessage = error.localizedDescription
                isSending = false
            }
        }
    }

    nonisolated func executeNotebookPrompt(_ prompt: String, projectURL: URL) async -> Result<NotebookAIResult, NotebookAIExecutionError> {
        let configuration = await MainActor.run { () -> (String?, String, AIContextGrantSnapshot) in
            let key = try? auth.resolvedAPIKey()
            let grants = AIContextGrantSnapshot(projectFiles: policy.projectFiles, gitDiff: policy.gitDiff)
            return (key ?? nil, auth.model, grants)
        }
        guard let key = configuration.0, !key.isEmpty else {
            return .failure(.unavailable("OpenAI is not configured."))
        }
        do {
            let result = try await OpenAIResponsesClient(apiKey: key, model: configuration.1).respond(
                prompt: prompt,
                projectURL: projectURL,
                context: .empty,
                grants: configuration.2
            )
            return .success(NotebookAIResult(text: result.text, provider: "openai:\(configuration.1)", requestID: result.id))
        } catch {
            return .failure(.failed(error.localizedDescription))
        }
    }

    private func boundedTranscript(_ messages: ArraySlice<AIConversationMessage>) -> String {
        let selected = messages.suffix(16)
        var value = selected.map { message in "\(message.role.rawValue.uppercased()): \(message.text)" }.joined(separator: "\n\n")
        if value.count > 24_000 { value = String(value.suffix(24_000)) }
        return value.isEmpty ? "" : "<conversation_history>\n\(value)\n</conversation_history>"
    }

    private func persist() async {
        guard let conversation else { return }
        await AIConversationStore.save(conversation)
    }
}

enum AIWorkspaceError: LocalizedError {
    case notConfigured
    var errorDescription: String? { "Configure an OpenAI API key before using AI." }
}

enum AIConversationStore {
    static func load(projectURL: URL) async -> AIConversation? {
        await Task.detached(priority: .utility) {
            let directory = directoryURL(projectPath: projectURL.standardizedFileURL.path)
            guard let urls = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]) else { return nil }
            let candidates = urls.filter { $0.pathExtension == "json" }.sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left > right
            }
            guard let url = candidates.first, let data = try? Data(contentsOf: url) else { return nil }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try? decoder.decode(AIConversation.self, from: data)
        }.value
    }

    static func save(_ conversation: AIConversation) async {
        await Task.detached(priority: .utility) {
            let directory = directoryURL(projectPath: conversation.projectPath)
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("\(conversation.id.uuidString).json")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(conversation) { try? data.write(to: url, options: .atomic) }
        }.value
    }

    private static func directoryURL(projectPath: String) -> URL {
        let digest = SHA256.hash(data: Data(projectPath.utf8)).prefix(16).map { String(format: "%02x", $0) }.joined()
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("FCF-Laboratory", isDirectory: true)
            .appendingPathComponent("Conversations", isDirectory: true)
            .appendingPathComponent(digest, isDirectory: true)
    }
}
