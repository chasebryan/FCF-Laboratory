import AppKit
import Foundation

@MainActor
final class GitHubAuthService: ObservableObject {
    enum CredentialSource: String, Sendable, Equatable {
        case keychain
        case githubCLI
        case deviceFlow
    }

    enum Status: Equatable {
        case signedOut
        case authenticating
        case signedIn(GitHubAuthenticatedUser, CredentialSource)
        case failed(String)
    }

    struct DeviceAuthorization: Equatable {
        let userCode: String
        let verificationURI: URL
        let expiresAt: Date
    }

    @Published private(set) var status: Status = .signedOut
    @Published private(set) var deviceAuthorization: DeviceAuthorization?
    @Published var deviceClientID: String {
        didSet { UserDefaults.standard.set(deviceClientID, forKey: clientIDKey) }
    }

    private let clientIDKey = "FCFLaboratory.GitHubClientID"
    private let ignoreCLIKey = "FCFLaboratory.GitHubIgnoreCLI"
    private let keychainAccount = "github.access-token"
    private var deviceTask: Task<Void, Never>?

    init() {
        deviceClientID = ProcessInfo.processInfo.environment["FCF_GITHUB_CLIENT_ID"]
            ?? UserDefaults.standard.string(forKey: "FCFLaboratory.GitHubClientID")
            ?? ""
    }

    var authenticatedUser: GitHubAuthenticatedUser? {
        if case .signedIn(let user, _) = status { return user }
        return nil
    }

    func refresh() {
        deviceTask?.cancel()
        status = .authenticating
        Task {
            do {
                guard let credential = try await resolveCredential() else {
                    status = .signedOut
                    return
                }
                let user = try await GitHubAPIClient(token: credential.token).authenticatedUser()
                status = .signedIn(user, credential.source)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func storePersonalAccessToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        status = .authenticating
        Task {
            do {
                let user = try await GitHubAPIClient(token: trimmed).authenticatedUser()
                try SecureCredentialStore.write(trimmed, account: keychainAccount)
                UserDefaults.standard.set(false, forKey: ignoreCLIKey)
                status = .signedIn(user, .keychain)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func useGitHubCLI() {
        UserDefaults.standard.set(false, forKey: ignoreCLIKey)
        status = .authenticating
        Task {
            do {
                guard let token = await githubCLIToken() else {
                    throw GitHubAuthError.cliUnavailable
                }
                let user = try await GitHubAPIClient(token: token).authenticatedUser()
                status = .signedIn(user, .githubCLI)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    func beginDeviceFlow() {
        let clientID = deviceClientID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clientID.isEmpty else {
            status = .failed("Configure a GitHub App client ID before starting device authorization.")
            return
        }

        deviceTask?.cancel()
        status = .authenticating
        deviceTask = Task {
            do {
                let authorization = try await requestDeviceAuthorization(clientID: clientID)
                deviceAuthorization = DeviceAuthorization(
                    userCode: authorization.userCode,
                    verificationURI: authorization.verificationURI,
                    expiresAt: Date().addingTimeInterval(TimeInterval(authorization.expiresIn))
                )
                NSWorkspace.shared.open(authorization.verificationURI)
                let token = try await pollForDeviceToken(
                    clientID: clientID,
                    deviceCode: authorization.deviceCode,
                    interval: authorization.interval,
                    expiresIn: authorization.expiresIn
                )
                try Task.checkCancellation()
                let user = try await GitHubAPIClient(token: token).authenticatedUser()
                try SecureCredentialStore.write(token, account: keychainAccount)
                UserDefaults.standard.set(false, forKey: ignoreCLIKey)
                deviceAuthorization = nil
                status = .signedIn(user, .deviceFlow)
            } catch is CancellationError {
                deviceAuthorization = nil
                status = .signedOut
            } catch {
                deviceAuthorization = nil
                status = .failed(error.localizedDescription)
            }
        }
    }

    func signOut() {
        deviceTask?.cancel()
        deviceTask = nil
        try? SecureCredentialStore.delete(account: keychainAccount)
        UserDefaults.standard.set(true, forKey: ignoreCLIKey)
        deviceAuthorization = nil
        status = .signedOut
    }

    func resolvedToken() async throws -> String? {
        try await resolveCredential()?.token
    }

    private func resolveCredential() async throws -> (token: String, source: CredentialSource)? {
        if let stored = try SecureCredentialStore.read(account: keychainAccount), !stored.isEmpty {
            return (stored, .keychain)
        }
        if UserDefaults.standard.bool(forKey: ignoreCLIKey) { return nil }
        if let cli = await githubCLIToken() {
            return (cli, .githubCLI)
        }
        return nil
    }

    private func githubCLIToken() async -> String? {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["gh", "auth", "token"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return nil
            }
            guard process.terminationStatus == 0 else { return nil }
            let token = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return token?.isEmpty == false ? token : nil
        }.value
    }

    private func requestDeviceAuthorization(clientID: String) async throws -> GitHubDeviceAuthorizationResponse {
        var request = URLRequest(url: URL(string: "https://github.com/login/device/code")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formData([
            "client_id": clientID,
            "scope": "repo read:user workflow",
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GitHubAuthError.deviceAuthorizationFailed
        }
        return try JSONDecoder().decode(GitHubDeviceAuthorizationResponse.self, from: data)
    }

    private func pollForDeviceToken(clientID: String, deviceCode: String, interval: Int, expiresIn: Int) async throws -> String {
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))
        var pollingInterval = max(interval, 5)

        while Date() < deadline {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(pollingInterval))

            var request = URLRequest(url: URL(string: "https://github.com/login/oauth/access_token")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = formData([
                "client_id": clientID,
                "device_code": deviceCode,
                "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
            ])

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw GitHubAuthError.deviceAuthorizationFailed
            }
            let decoded = try JSONDecoder().decode(GitHubDeviceTokenResponse.self, from: data)
            if let token = decoded.accessToken { return token }

            switch decoded.error {
            case "authorization_pending": continue
            case "slow_down": pollingInterval += 5
            case "expired_token": throw GitHubAuthError.deviceCodeExpired
            case "access_denied": throw GitHubAuthError.accessDenied
            default: throw GitHubAuthError.deviceAuthorizationFailed
            }
        }
        throw GitHubAuthError.deviceCodeExpired
    }

    private func formData(_ values: [String: String]) -> Data {
        let allowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+&="))
        let body = values.sorted { $0.key < $1.key }.map { key, value in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }.joined(separator: "&")
        return Data(body.utf8)
    }
}

private struct GitHubDeviceAuthorizationResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationURI: URL
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURI = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

private struct GitHubDeviceTokenResponse: Decodable {
    let accessToken: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
    }
}

enum GitHubAuthError: LocalizedError {
    case cliUnavailable
    case deviceAuthorizationFailed
    case deviceCodeExpired
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .cliUnavailable: return "GitHub CLI is not authenticated or not installed."
        case .deviceAuthorizationFailed: return "GitHub device authorization failed."
        case .deviceCodeExpired: return "The GitHub device authorization code expired."
        case .accessDenied: return "GitHub authorization was denied."
        }
    }
}
