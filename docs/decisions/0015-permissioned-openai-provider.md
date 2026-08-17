# ADR 0015: Permissioned OpenAI provider and local conversation state

Status: accepted

## Context

FCF-Laboratory needs first-class AI assistance without silently uploading an entire workspace, coupling notebooks to one model vendor, or storing API credentials in project files. The provider must support ordinary conversation, notebook AI cells, and tool-assisted project reasoning through the existing `FCF-AI-v1` boundary.

## Decision

The native OpenAI provider uses the Responses API. API credentials come from `OPENAI_API_KEY` or the macOS Keychain. The default model is configurable and initially follows the current GPT-5.6 alias.

Workspace context is deny-by-default. The user independently grants:

- active document content
- active notebook content
- active terminal transcript
- project-file access
- Git working diff access

Only project-file and Git-diff grants create callable workspace tools. If a grant is absent, its tool definition is omitted from the OpenAI request entirely.

Laboratory uses `store: false`. For function-call continuation, it requests encrypted reasoning content and manually replays the response output items together with `function_call_output` items. This avoids relying on remotely stored Responses application state for the tool loop.

AI conversation transcripts are persisted locally under the user's Application Support directory, namespaced by a digest of the project path. They are not written into the project repository by default. Notebook AI responses are separately captured as notebook execution evidence.

## Authentication

The working provider path is OpenAI API authentication. A future ChatGPT identity adapter remains a separate credential-provider slot and must use an officially documented external-app sign-in flow when FCF-Laboratory has the required registration/configuration. Laboratory must not invent or scrape ChatGPT session credentials.

## Security and privacy properties

- API keys never enter project files or notebook provenance
- workspace context is explicit and revocable
- tool paths are constrained to the open project
- file reads and tool outputs are bounded
- tool data is treated as untrusted input by provider instructions
- tool-call loops are bounded
- a stable privacy-preserving safety identifier is sent with API requests

## Consequences

The same AI controller serves the transient chat surface and notebook AI cells while the project remains usable without OpenAI configuration. Other AI providers can implement `FCF-AI-v1` without changing workspace semantics.
