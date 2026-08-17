import AppKit
import SwiftUI

struct GitHubWorkspacePanel: View {
    @ObservedObject var controller: GitHubWorkspaceController
    let remote: GitHubRemoteIdentity?

    @State private var issueTitle = ""
    @State private var issueBody = ""
    @State private var isCreatingIssue = false
    @State private var writeError: String?

    var body: some View {
        VStack(spacing: 0) {
            GitHubAuthPanel(auth: controller.auth) {
                controller.refresh(remote: remote)
            }

            if controller.auth.authenticatedUser != nil {
                Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1)
                repositoryContent
            }
        }
        .onAppear {
            controller.auth.refresh()
            controller.refresh(remote: remote)
        }
        .onChange(of: controller.auth.authenticatedUser) { _, user in
            if user != nil { controller.refresh(remote: remote) }
        }
    }

    @ViewBuilder
    private var repositoryContent: some View {
        if let remote {
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Text(remote.slug)
                        .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    if controller.isLoading { ProgressView().controlSize(.mini) }
                    Button("Refresh") { controller.refresh(remote: remote) }
                        .buttonStyle(.plain)
                        .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 14)
                .frame(height: 38)

                if let error = controller.errorMessage {
                    Text(error)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if let overview = controller.overview {
                    HSplitView {
                        repositoryLists(overview)
                            .frame(minWidth: 350)
                        issueComposer(remote)
                            .frame(minWidth: 240)
                    }
                    .frame(minHeight: 270)
                } else if !controller.isLoading {
                    Text("Repository data will appear after authentication and refresh.")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 220)
                }
            }
        } else {
            Text("Open a project with a GitHub origin to use repository operations.")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, minHeight: 220)
        }
    }

    private func repositoryLists(_ overview: GitHubRepositoryOverview) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                repoSection("PULL REQUESTS") {
                    ForEach(Array(overview.pullRequests.prefix(12))) { item in
                        repoRow("#\(item.number)", item.title, item.htmlURL)
                    }
                }
                repoSection("ISSUES") {
                    ForEach(Array(overview.issues.prefix(12))) { item in
                        repoRow("#\(item.number)", item.title, item.htmlURL)
                    }
                }
                repoSection("ACTIONS") {
                    ForEach(Array(overview.workflowRuns.prefix(12))) { run in
                        repoRow(run.conclusion ?? run.status, run.name, run.htmlURL)
                    }
                }
            }
            .padding(12)
        }
    }

    private func repoSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.tertiary)
            content()
        }
    }

    private func repoRow(_ badge: String, _ title: String, _ url: String) -> some View {
        Button {
            if let url = URL(string: url) { NSWorkspace.shared.open(url) }
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(badge)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(width: 54, alignment: .leading)
                Text(title)
                    .font(.system(size: 10.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .frame(height: 25)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func issueComposer(_ remote: GitHubRemoteIdentity) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("NEW ISSUE")
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
                .foregroundStyle(.tertiary)

            TextField("Title", text: $issueTitle)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))

            TextEditor(text: $issueBody)
                .font(.system(size: 10.5))
                .scrollContentBackground(.hidden)
                .padding(5)
                .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 7))
                .frame(minHeight: 105)

            if let writeError {
                Text(writeError)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

            Button {
                createIssue(remote)
            } label: {
                if isCreatingIssue { ProgressView().controlSize(.mini) }
                else { Text("Create Issue") }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(issueTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isCreatingIssue)

            Spacer()
        }
        .padding(12)
    }

    private func createIssue(_ remote: GitHubRemoteIdentity) {
        let title = issueTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        isCreatingIssue = true
        writeError = nil
        Task {
            do {
                try await controller.createIssue(remote: remote, title: title, body: issueBody)
                issueTitle = ""
                issueBody = ""
            } catch {
                writeError = error.localizedDescription
            }
            isCreatingIssue = false
        }
    }
}

private struct GitHubAuthPanel: View {
    @ObservedObject var auth: GitHubAuthService
    let authenticated: () -> Void

    @State private var token = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                status
                Spacer()
                if auth.authenticatedUser != nil {
                    Button("Sign Out") { auth.signOut() }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                }
            }

            if auth.authenticatedUser == nil {
                HStack(spacing: 8) {
                    Button("Use GitHub CLI") { auth.useGitHubCLI() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    SecureField("Personal access token", text: $token)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10.5))
                    Button("Store in Keychain") {
                        auth.storePersonalAccessToken(token)
                        token = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(token.isEmpty)
                }

                HStack(spacing: 8) {
                    TextField("GitHub App client ID", text: $auth.deviceClientID)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 10.5))
                    Button("Device Sign In") { auth.beginDeviceFlow() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(auth.deviceClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let device = auth.deviceAuthorization {
                    HStack(spacing: 8) {
                        Text(device.userCode)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .textSelection(.enabled)
                        Text("Enter this code in the GitHub window that opened.")
                            .font(.system(size: 9.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(12)
    }

    @ViewBuilder
    private var status: some View {
        switch auth.status {
        case .signedOut:
            Label("GitHub not connected", systemImage: "person.crop.circle.badge.xmark")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.secondary)
        case .authenticating:
            HStack(spacing: 7) {
                ProgressView().controlSize(.mini)
                Text("Authenticating with GitHub")
                    .font(.system(size: 10.5, weight: .medium))
            }
        case .signedIn(let user, let source):
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle")
                Text(user.name ?? user.login)
                    .font(.system(size: 10.5, weight: .semibold))
                Text("@\(user.login) · \(source.rawValue)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
            .onAppear { authenticated() }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 2) {
                Text("GitHub authentication failed")
                    .font(.system(size: 10.5, weight: .semibold))
                Text(message)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
