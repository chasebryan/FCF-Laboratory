import Foundation

struct GitHubAuthenticatedUser: Codable, Hashable, Sendable {
    let login: String
    let name: String?
    let avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case login
        case name
        case avatarURL = "avatar_url"
    }
}

struct GitHubPullRequestSummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let draft: Bool?
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case id, number, title, state, draft
        case htmlURL = "html_url"
    }
}

private struct GitHubPullRequestMarker: Codable, Hashable, Sendable {
    let url: String?
}

struct GitHubIssueSummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let number: Int
    let title: String
    let state: String
    let htmlURL: String
    private let pullRequest: GitHubPullRequestMarker?

    enum CodingKeys: String, CodingKey {
        case id, number, title, state
        case htmlURL = "html_url"
        case pullRequest = "pull_request"
    }

    var isPullRequest: Bool { pullRequest != nil }
}

struct GitHubWorkflowRunSummary: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let status: String
    let conclusion: String?
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case id, name, status, conclusion
        case htmlURL = "html_url"
    }
}

struct GitHubRepositoryOverview: Hashable, Sendable {
    let pullRequests: [GitHubPullRequestSummary]
    let issues: [GitHubIssueSummary]
    let workflowRuns: [GitHubWorkflowRunSummary]
}

actor GitHubAPIClient {
    private let token: String
    private let session: URLSession

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func authenticatedUser() async throws -> GitHubAuthenticatedUser {
        try await request(path: "/user", method: "GET", body: nil)
    }

    func repositoryOverview(remote: GitHubRemoteIdentity) async throws -> GitHubRepositoryOverview {
        async let pulls: [GitHubPullRequestSummary] = request(
            path: "/repos/\(remote.owner)/\(remote.repository)/pulls?state=open&per_page=30",
            method: "GET",
            body: nil
        )
        async let allIssues: [GitHubIssueSummary] = request(
            path: "/repos/\(remote.owner)/\(remote.repository)/issues?state=open&per_page=30",
            method: "GET",
            body: nil
        )
        async let runs: WorkflowRunsEnvelope = request(
            path: "/repos/\(remote.owner)/\(remote.repository)/actions/runs?per_page=20",
            method: "GET",
            body: nil
        )

        let (pullRequests, rawIssues, workflowRuns) = try await (pulls, allIssues, runs)
        return GitHubRepositoryOverview(
            pullRequests: pullRequests,
            issues: rawIssues.filter { !$0.isPullRequest },
            workflowRuns: workflowRuns.workflowRuns
        )
    }

    func createIssue(remote: GitHubRemoteIdentity, title: String, body: String) async throws -> GitHubIssueSummary {
        let payload = try JSONEncoder().encode(CreateIssueRequest(title: title, body: body))
        return try await request(
            path: "/repos/\(remote.owner)/\(remote.repository)/issues",
            method: "POST",
            body: payload
        )
    }

    private func request<T: Decodable>(path: String, method: String, body: Data?) async throws -> T {
        guard let url = URL(string: "https://api.github.com\(path)") else {
            throw GitHubAPIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("FCF-Laboratory", forHTTPHeaderField: "User-Agent")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(GitHubErrorEnvelope.self, from: data).message)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw GitHubAPIError.http(http.statusCode, message)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.decoding(error.localizedDescription)
        }
    }
}

private struct WorkflowRunsEnvelope: Codable {
    let workflowRuns: [GitHubWorkflowRunSummary]
    enum CodingKeys: String, CodingKey { case workflowRuns = "workflow_runs" }
}

private struct CreateIssueRequest: Codable {
    let title: String
    let body: String
}

private struct GitHubErrorEnvelope: Codable {
    let message: String
}

enum GitHubAPIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case http(Int, String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid GitHub API URL."
        case .invalidResponse: return "GitHub returned an invalid response."
        case .http(let code, let message): return "GitHub API \(code): \(message)"
        case .decoding(let message): return "Unable to decode GitHub response: \(message)"
        }
    }
}
