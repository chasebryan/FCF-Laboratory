# ADR 0003: Minimal interface by default

## Status

Accepted.

## Decision

FCF-Laboratory will default to a stripped, content-first workspace. Navigators, inspectors, terminals, Git surfaces, AI, engine controls, and other machinery are summoned when needed rather than permanently occupying the interface.

The command surface is a primary interaction mechanism. Technical objects open into a common workspace model rather than separate application modes.

## Rationale

The application is intended for long periods of concentrated work. Visible complexity must not grow linearly with capability.

## Consequences

- New permanent chrome requires explicit design justification.
- Empty space is protected.
- Tabs may disappear when only one object is open.
- Context-sensitive commands should expose power without adding permanent controls.
- Feature reviews include visual-density impact, not only functional correctness.
