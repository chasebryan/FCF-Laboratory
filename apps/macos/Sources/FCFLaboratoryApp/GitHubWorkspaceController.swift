import Foundation

@MainActor
final class GitHubWorkspaceController: ObservableObject {
    let auth = GitHubAuthService()

    @Published private(set) var overview: GitHubRepositoryOverview?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    func refresh(remote: GitHubRemoteIdentity?) {
        guard let remote else {
            overview = nil
            errorMessage = nil
            return
        }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                guard let token = try await auth.resolvedToken() else {
                    overview = nil
                    isLoading = false
                    return
                }
                overview = try await GitHubAPIClient(token: token).repositoryOverview(remote: remote)
                isLoading = false
            } catch {
                overview = nil
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }

    func createIssue(remote: GitHubRemoteIdentity, title: String, body: String) async throws {
        guard let token = try await auth.resolvedToken() else {
            throw GitHubWorkspaceError.notAuthenticated
        }
        let client = GitHubAPIClient(token: token)
        _ = try await client.createIssue(remote: remote, title: title, body: body)
        overview = try await client.repositoryOverview(remote: remote)
    }
}

enum GitHubWorkspaceError: LocalizedError {
    case notAuthenticated
    var errorDescription: String? { "GitHub authentication is required." }
}
