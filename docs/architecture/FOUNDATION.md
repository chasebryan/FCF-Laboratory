# FCF-Laboratory Foundation

## Purpose

FCF-Laboratory is a universal technical workspace for creating, computing, investigating, verifying, and publishing technical work without forcing the user to live across a pile of disconnected applications.

The product is not a web application and is not an engine monorepo. It is a native workspace shell around a portable core and explicit integration protocols.

## Architectural laws

1. **Native outside, portable inside.** Platform applications are native. Shared models, protocols, indexing, workspace semantics, and orchestration remain portable.
2. **The Laboratory owns the laboratory, not the instruments.** CENTL, CBX, SageMath, PARI/GP, Python, and future engines remain external systems.
3. **The work dominates the screen.** Permanent chrome is presumed guilty until proven necessary.
4. **No blocking machinery.** Indexing, Git, AI, engine execution, network work, and expensive parsing never block the interactive surface.
5. **Architecture is metadata, never business logic.** Platform-specific behavior is isolated behind platform boundaries.
6. **Workspace artifacts are portable.** Stored project data must not depend on absolute machine paths for scientific meaning.
7. **Standards before reinvention.** Prefer Git, LSP, DAP, native file formats, and stable protocols before creating FCF-specific replacements.
8. **Explicit context boundaries.** AI providers receive only the workspace context the user grants.
9. **Root austerity.** Files belong in folders unless tooling or repository semantics materially require root placement.
10. **Beauty and performance are correctness properties.** A feature that is visibly cluttered, inconsistent, laggy, or jarring is incomplete.

## Platform matrix

| Platform | Architecture | Status |
| --- | --- | --- |
| macOS | arm64 | reference experience |
| Linux | x86_64 | supported core target |
| Linux | arm64 | supported core target |
| Windows | x86_64 | supported core target |

Intel macOS is intentionally out of scope.

## Layers

### Native application layer

Owns windows, menus, keyboard interaction, platform materials, accessibility, drag and drop, file dialogs, system integration, and native presentation.

The macOS application uses SwiftUI and AppKit where deeper desktop control is warranted.

### Portable core

Owns workspace identity, portable project objects, orchestration primitives, engine/provider contracts, provenance models, indexing contracts, Git abstractions, and non-UI business logic.

The initial implementation uses Rust.

### Integration layer

Adapters translate external engines and providers into FCF protocols. They do not vendor the external project source trees.

### Workspace layer

A workspace is a graph of technical objects, not merely a directory tree. A source file, notebook, dataset, paper, experiment, GitHub issue, pull request, terminal, AI session, engine result, or witness may all be opened as workspace objects.
