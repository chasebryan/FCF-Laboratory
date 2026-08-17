# ADR 0006: Native project discovery and editor surface

Status: accepted

## Decision

FCF-Laboratory discovers local project files asynchronously and opens text-editable files in a native AppKit text surface.

Project discovery is bounded, skips generated/dependency directories by default, ignores symbolic links during recursive discovery, and never blocks project opening. The project container is distinct from open workspace objects: opening a project does not create a synthetic editor tab.

The first macOS editor is built on `NSTextView` rather than a web editor or SwiftUI `TextEditor`. File reads and writes occur outside the UI actor. Undo, native find behavior, native scrolling, monospaced system typography, and standard macOS text interaction remain available.

## Consequences

- The editor can evolve toward TextKit 2, syntax layers, diagnostics, LSP, large-file strategies, and semantic tooling without replacing a browser-backed editor.
- Project indexing can evolve independently from rendering and language intelligence.
- Generated directories such as `.git`, `.build`, `target`, and `node_modules` do not flood the initial navigator.
- Binary and specialized objects remain first-class workspace objects but require dedicated renderers instead of being coerced into the text editor.
- The visible UI remains minimal: project files live behind the summonable navigator, tabs appear only when multiple objects are open, and unsaved state is represented by a small status mark rather than permanent chrome.
