# OpenAI / ChatGPT Integration

FCF-Laboratory's OpenAI provider is implemented behind `FCF-AI-v1`.

## Working authentication

The native macOS client resolves OpenAI API credentials from:

1. `OPENAI_API_KEY`, when present in the process environment
2. a key explicitly stored by the user in the macOS Keychain

Credentials are never written into project files, notebooks, provenance, or plaintext settings.

## Responses API

The provider uses `POST /v1/responses`. The model is user-configurable and defaults to the current GPT-5.6 alias. Responses are requested with `store: false`.

Laboratory can expose permissioned workspace function tools for project-file reads/search and Git working diffs. Tool definitions are omitted unless the matching context grant is enabled. Function-call continuations manually replay response output items and encrypted reasoning content instead of depending on remotely stored response state.

## Context permissions

Workspace context is deny-by-default. Users may independently allow active document, notebook, terminal transcript, project files, and Git diff context. Revoking a permission immediately removes that scope from future requests.

## Conversations and notebooks

Interactive AI conversations are stored locally under Application Support, outside the project repository. Notebook AI cells use the same OpenAI provider and store their returned result in notebook execution evidence.

## ChatGPT identity

The provider architecture reserves a distinct ChatGPT identity adapter. FCF-Laboratory must only enable low-friction ChatGPT sign-in when an officially supported external-app authentication flow is available and the application has the required OpenAI registration/configuration. It must never reuse browser cookies, scrape ChatGPT sessions, or fabricate OAuth endpoints.
