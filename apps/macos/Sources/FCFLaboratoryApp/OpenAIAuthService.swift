import Foundation

@MainActor
final class OpenAIAuthService: ObservableObject {
    enum CredentialSource: String, Sendable, Equatable {
        case environment
        case keychain
    }

    enum Status: Equatable {
        case unconfigured
        case configured(CredentialSource)
        case failed(String)
    }

    @Published private(set) var status: Status = .unconfigured
    @Published var model: String {
        didSet { UserDefaults.standard.set(model, forKey: modelKey) }
    }

    private let keychainAccount = "openai.api-key"
    private let modelKey = "FCFLaboratory.OpenAIModel"

    init() {
        model = UserDefaults.standard.string(forKey: modelKey) ?? "gpt-5.6"
        refresh()
    }

    func refresh() {
        do {
            if let environment = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !environment.isEmpty {
                status = .configured(.environment)
            } else if let stored = try SecureCredentialStore.read(account: keychainAccount), !stored.isEmpty {
                status = .configured(.keychain)
            } else {
                status = .unconfigured
            }
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func storeAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try SecureCredentialStore.write(trimmed, account: keychainAccount)
            status = .configured(.keychain)
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func removeStoredAPIKey() {
        do {
            try SecureCredentialStore.delete(account: keychainAccount)
            refresh()
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func resolvedAPIKey() throws -> String? {
        if let environment = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !environment.isEmpty {
            return environment
        }
        return try SecureCredentialStore.read(account: keychainAccount)
    }
}
