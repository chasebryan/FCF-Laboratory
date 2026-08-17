import XCTest
@testable import FCFLaboratoryApp

final class ProviderServicesTests: XCTestCase {
    func testGitHubModelsDecodePullRequestsSeparatelyFromIssues() throws {
        let pullJSON = #"{"id":1,"number":7,"title":"Foundation","state":"open","draft":true,"html_url":"https://github.com/fcf/lab/pull/7"}"#.data(using: .utf8)!
        let pull = try JSONDecoder().decode(GitHubPullRequestSummary.self, from: pullJSON)
        XCTAssertEqual(pull.number, 7)
        XCTAssertEqual(pull.draft, true)

        let issueJSON = #"{"id":2,"number":8,"title":"Issue","state":"open","html_url":"https://github.com/fcf/lab/issues/8"}"#.data(using: .utf8)!
        let issue = try JSONDecoder().decode(GitHubIssueSummary.self, from: issueJSON)
        XCTAssertFalse(issue.isPullRequest)

        let issueEndpointPullJSON = #"{"id":3,"number":9,"title":"PR through issues endpoint","state":"open","html_url":"https://github.com/fcf/lab/pull/9","pull_request":{"url":"https://api.github.com/repos/fcf/lab/pulls/9"}}"#.data(using: .utf8)!
        let issueEndpointPull = try JSONDecoder().decode(GitHubIssueSummary.self, from: issueEndpointPullJSON)
        XCTAssertTrue(issueEndpointPull.isPullRequest)
    }

    func testAIContextSnapshotContainsOnlySuppliedScopes() {
        let snapshot = AIWorkspaceContextSnapshot(activeDocument: "let x = 1", activeNotebook: nil, terminalTranscript: nil)
        XCTAssertTrue(snapshot.preamble.contains("<active_document>"))
        XCTAssertTrue(snapshot.preamble.contains("let x = 1"))
        XCTAssertFalse(snapshot.preamble.contains("active_notebook"))
        XCTAssertFalse(snapshot.preamble.contains("terminal_transcript"))
    }

    func testConversationRoundTripPreservesProviderResponseIdentity() throws {
        let message = AIConversationMessage(
            id: UUID(),
            role: .assistant,
            text: "result",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            providerResponseID: "resp_123"
        )
        let conversation = AIConversation(id: UUID(), projectPath: "/tmp/project", messages: [message], updatedAt: message.createdAt)
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(AIConversation.self, from: encoder.encode(conversation))
        XCTAssertEqual(decoded, conversation)
    }
}
