# Performance Budgets

FCF-Laboratory treats responsiveness as part of product correctness.

These are engineering targets, not public guarantees.

## Interaction

- Keystroke-to-render target: under 16 ms for normal editing paths.
- Command invocation should feel immediate.
- Scrolling must remain smooth under large documents and logs.
- Opening and closing panels must never wait on network, Git, AI, or engines.

## Startup

- Render useful native window content before background discovery completes.
- Warm launch target: under 500 ms to an interactive window where practical.
- Cold launch target: under 1.2 s to an interactive window where practical.
- Engine discovery, Git status, indexing, and provider connection happen asynchronously.

## Workspace

- Project opening is progressive.
- File tree and last-open object should appear before indexing finishes.
- Search should return first useful results incrementally.
- No full-workspace scan belongs on the UI thread.

## Background systems

The following are always asynchronous from the presentation layer:

- Git operations beyond trivial in-memory state
- GitHub network calls
- AI/provider calls
- engine execution
- notebook execution
- project indexing
- repository search
- provenance calculation
- expensive parsing
- filesystem scans

## Measurement

Performance regressions are bugs. Platform applications should be profiled with native tools and shared Rust components benchmarked independently. Feature work that violates these budgets should either be redesigned or explicitly documented as an exception.
