# ADR 0010: Keystrokes Do Not Run Intelligence

Status: accepted

The editor input path must stay lightweight. Syntax analysis, symbols, project search, Git inspection, language-server discovery, tasks, engines, and AI are not allowed to become synchronous keystroke work.

## Rules

- Text input updates the document model immediately.
- Syntax highlighting is debounced and computed off the main actor, then applied only if the source snapshot is still current.
- Background analysis tasks are cancellable when newer input supersedes them.
- Expensive intelligence must tolerate being stale for a fraction of a second rather than stealing an interaction frame.
- Native AppKit mutation remains on the main actor.
- Foundation services receive unit tests on macOS arm64.
- CI must build the native app, run native service tests, and run the portable-core tests on Apple Silicon.

The target is simple: intelligence may arrive after the keystroke; the keystroke must never arrive after intelligence.
