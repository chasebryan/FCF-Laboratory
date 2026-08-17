# ADR 0004: Contextual command surface

## Status

Accepted.

## Decision

FCF-Laboratory will use a searchable contextual command surface as a primary route to capability. This allows Git, GitHub, AI, engines, notebooks, experiments, and project actions to remain accessible without requiring permanent panels or toolbar controls.

## Consequences

- Commands must be registerable by core subsystems and integrations.
- Command availability may depend on active object type, selection, workspace state, and provider/engine readiness.
- Command registration must not permit integrations to inject arbitrary permanent chrome.
- Keyboard and discoverability are equal concerns.
