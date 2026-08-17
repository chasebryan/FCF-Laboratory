# GitHub Integration

Git is core workspace infrastructure. GitHub is a first-class provider layered on top of Git rather than a replacement for it.

## Planned native capabilities

- repository clone/open
- branch and worktree awareness
- issues
- pull requests
- reviews and comments
- Actions/check status
- releases
- repository metadata

GitHub objects should open as ordinary Laboratory workspace objects and participate in command/context actions.

Network access, authentication, and synchronization remain asynchronous. A GitHub outage must never make a local project unusable.

Provider-specific code belongs here or in a dedicated portable provider package as the implementation grows. Git repository semantics belong in the shared Git layer, not in this adapter.
