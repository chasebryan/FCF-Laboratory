# ADR 0014: GitHub authentication and repository-provider boundary

Status: accepted

## Context

FCF-Laboratory needs GitHub integration without conflating local Git with hosted repository operations or baking credentials into project files. Local Git must remain usable without a network account. Hosted GitHub capabilities require authenticated API access and must use secure local credential storage.

GitHub supports several authentication environments. Laboratory also needs to work well for developers who already use the GitHub CLI.

## Decision

Local repository state remains owned by the local Git integration. GitHub-hosted operations are owned by a separate `GitHubWorkspaceController` and `GitHubAPIClient`.

The macOS client resolves credentials through one of three explicit sources:

1. an FCF-Laboratory token stored in the macOS Keychain
2. an already-authenticated GitHub CLI session, used as a credential broker without copying its token into Laboratory storage
3. GitHub device authorization when a real GitHub App/OAuth client ID is configured

No GitHub client secret is embedded in the desktop application. Device-flow client IDs are configuration, not secrets. Personal access tokens are optional compatibility credentials and are stored only in Keychain.

The initial authenticated repository surface supports:

- account identity validation
- open pull-request summaries
- open issue summaries
- recent Actions workflow runs
- issue creation

Repository links open through the system browser. Additional write operations must be added through typed API methods, not arbitrary shell commands containing credentials.

## Security properties

- tokens never enter project files or notebook provenance
- bearer tokens are not shown in UI after entry
- `gh auth token` output is held in memory only
- signing out removes Laboratory-owned Keychain credentials
- the user can disable automatic reuse of GitHub CLI authentication
- network operations are isolated from local Git status/diff operations

## Consequences

Laboratory can evolve toward a fine-grained GitHub App permission model without rewriting workspace logic, while remaining useful before an FCF GitHub App registration is provisioned.
