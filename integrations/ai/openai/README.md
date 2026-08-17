# OpenAI / ChatGPT Integration

This directory is reserved for the native OpenAI provider adapter.

The implementation must use current official OpenAI authentication and API guidance when it is built. Do not embed API secrets in the application bundle, repository, project files, notebooks, or plaintext settings.

The intended user experience is low-friction interactive sign-in where officially supported, with an advanced developer/API configuration path where appropriate.

OpenAI-specific behavior must remain behind `FCF-AI-v1` so the Laboratory workspace is not coupled to one provider.
