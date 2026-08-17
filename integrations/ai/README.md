# AI Integrations

Provider-specific adapters live here. They implement `FCF-AI-v1` while keeping provider details outside the shared workspace model.

## OpenAI / ChatGPT

The OpenAI integration should use the simplest officially supported interactive authentication available to FCF-Laboratory at implementation time. Credentials must be stored through the host platform's secure secret-storage facilities and never committed or embedded into workspace artifacts.

ChatGPT should be summonable from the command surface and from contextual actions on Laboratory objects. It should not require a permanently visible chat panel.

## Other providers

Local and future remote providers should implement the same provider boundary where practical. Provider-specific features may extend the protocol without making the shared core dependent on them.
