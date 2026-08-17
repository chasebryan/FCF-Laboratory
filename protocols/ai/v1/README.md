# FCF AI Provider Protocol v1

**Protocol identifier:** `FCF-AI-v1`

FCF-Laboratory treats AI as a first-class capability without coupling the workspace model to a single provider.

## Principles

- Providers are replaceable; workspace semantics are not.
- ChatGPT/OpenAI may receive a premium native integration, but the core remains provider-independent.
- Authentication uses the provider's officially supported flow.
- Secrets never belong in a project, repository, notebook, or plaintext configuration file.
- Workspace context is granted explicitly.
- A provider must not silently receive the entire project merely because it is connected.
- Provider calls never block the interactive UI.

## Context grants

The protocol models context as explicit grants such as:

- current selection
- file
- folder
- workspace
- notebook
- experiment
- terminal
- Git diff/history
- GitHub issue or pull request
- engine result
- dataset
- paper
- witness

A grant may be one-time or persistent according to future user-controlled policy.

## Authentication boundary

Provider adapters own interactive authentication and secure credential persistence behind a platform secret-store abstraction. The portable core should only receive an authenticated provider session abstraction, never raw UI-specific login state.
