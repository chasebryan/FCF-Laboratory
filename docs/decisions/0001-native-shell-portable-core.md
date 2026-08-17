# ADR 0001: Native shells over a portable core

## Status

Accepted.

## Decision

FCF-Laboratory will use native platform application shells over a portable shared core.

The macOS reference application is Apple Silicon (`arm64`) only and uses SwiftUI plus AppKit where appropriate. Shared non-UI logic begins in Rust and must not assume a specific OS or CPU architecture.

FCF-Laboratory will not use Electron and will not ship its primary desktop experience as a browser application.

## Rationale

The product requires first-class native interaction, low latency, strong desktop integration, and a visual character that belongs on the host platform. Sharing every presentation primitive across operating systems would optimize source reuse at the expense of product quality.

The shared core preserves portability where it matters: workspace semantics, protocols, orchestration, indexing contracts, provenance, and computation models.

## Consequences

- Platform applications may differ visually while preserving workspace semantics.
- Native UI work is intentionally duplicated where that produces a better host-platform experience.
- Portable core APIs must remain presentation-agnostic.
- macOS Intel compatibility is not a release goal.
