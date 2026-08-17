# FCF-Laboratory

FCF-Laboratory is the Free Computation Foundation's native computational research workspace: a minimal, high-performance environment for code, research, notebooks, papers, Git, GitHub, AI-assisted work, external computation engines, experiments, and reproducible technical artifacts.

## North star

**Show the work, not the machinery.**

FCF-Laboratory is designed to feel quiet, precise, and unusually dense with capability. The default surface stays sparse. Tools appear when summoned, then get out of the way.

## Platform contract

- macOS: Apple Silicon (`arm64`) only.
- Linux shared core: `x86_64` and `arm64`.
- Windows shared core: `x86_64` initially.
- The shared core remains OS- and architecture-agnostic.
- FCF-Laboratory is a native standalone application, never a browser application or Electron shell.

## Foundation status

The current `foundation/v0` work establishes a real native macOS workspace rather than a mock interface. It includes:

- native SwiftUI/AppKit application shell with an Apple-Silicon compile guard
- portable Rust core and versioned engine/AI protocol packages
- project opening, recent projects, bounded asynchronous indexing, collapsed directory navigation, and hidden technical files
- `⌘P` Quick Open and bounded project-wide text search
- native AppKit source editor with line numbers, undo/find, save, dirty-state protection, language detection, lightweight syntax coloring, and local symbol navigation
- LSP server discovery and a transport boundary without fabricated semantic results
- native PDFKit paper viewing
- Git branch/working-tree inspection and per-change diffs
- local GitHub origin identity detection
- detected Cargo, Swift, and Pytest tasks with non-blocking execution
- transient command/intelligence surfaces instead of permanent dashboard clutter
- CENTL and CBX manifests as external instruments rather than vendored source
- explicit performance budgets and architecture decision records
- CI across Linux x86_64, Linux arm64, Windows x86_64, and macOS Apple Silicon
- native macOS service tests in addition to portable Rust tests

## Architecture

- `apps/` contains native platform applications.
- `packages/` contains portable implementation packages.
- `protocols/` contains stable contracts between Laboratory and external systems.
- `integrations/` contains adapters and provider-specific integration code, not vendored engines.
- `docs/` contains architecture, design, performance, and decision records.
- `.github/` contains repository automation only.

CENTL, CBX, and future computation engines remain independent repositories. Laboratory discovers and connects to them through the FCF Engine Protocol.

## Intentional planning boundary

The foundation does not guess at the architecture for four systems that materially shape the product:

1. interactive PTY terminal/session semantics
2. native notebook persistence, cell graph, execution, engine mapping, and provenance
3. authenticated GitHub operations and credential storage
4. authenticated OpenAI/ChatGPT integration and workspace-context permissions

Those systems should be designed deliberately rather than smuggled into the app as convenience code.

See `docs/architecture/FOUNDATION.md`, `docs/design/DESIGN-LANGUAGE.md`, `docs/performance/PERFORMANCE-BUDGETS.md`, and the ADRs under `docs/decisions/` before adding major features.
