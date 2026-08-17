# ADR 0007: Editor Intelligence Is Layered

Status: accepted

FCF-Laboratory keeps editor intelligence outside the text view. The native AppKit editor owns rendering, input, selection, undo, find, scrolling, and line presentation. Language detection, syntax spans, symbols, project search, language-server discovery, task execution, and Git workspace state are separate services.

This prevents language-specific logic from accumulating inside the UI and keeps the editor useful when optional tools are absent.

## Rules

- Language identity is derived from file metadata and, when useful, a small content prefix.
- Syntax highlighting is local and lightweight. It must never block opening or editing a document.
- Symbol extraction is a fast local fallback, not a substitute for semantic language tooling.
- LSP servers are discovered, never assumed. Missing servers are not errors.
- LSP transport is a protocol boundary; no fake completions or diagnostics are synthesized.
- Project-wide search is bounded by result count and file size.
- Build/test tasks execute outside the UI thread and do not require a shell when an executable plus arguments is sufficient.
- Git state and diffs are queried asynchronously.
- Native editor responsiveness outranks background intelligence.

The intended progression is local intelligence first, semantic server intelligence second, AI context third. Each layer can fail independently without taking the workspace down with it.
