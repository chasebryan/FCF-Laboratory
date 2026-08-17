# GitHub Integration

Git is core workspace infrastructure. GitHub is a first-class hosted provider layered on top of Git rather than a replacement for it.

## Implemented native capabilities

- local GitHub-origin detection
- authenticated account validation
- existing `gh` CLI authentication reuse without copying its token into Laboratory storage
- optional personal access token storage in macOS Keychain
- GitHub device authorization when a real GitHub App/OAuth client ID is configured
- open pull-request summaries
- open issue summaries
- recent Actions workflow runs
- issue creation

GitHub links open through the system browser. Network work remains asynchronous. A GitHub outage or signed-out account must never make the local Git project unusable.

## Authentication boundary

No client secret is embedded in the desktop application. Laboratory-owned bearer tokens live only in Keychain. GitHub CLI tokens are requested into memory when needed and are not copied into Laboratory persistence. A user may explicitly disable automatic reuse of GitHub CLI authentication.

Local branch/status/diff behavior belongs to the Git layer. Hosted issues, pull requests, Actions, and future reviews/releases belong to the GitHub provider layer.

See `docs/decisions/0014-github-auth-provider.md`.
