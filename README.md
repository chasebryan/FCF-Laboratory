# FCF-Laboratory

FCF-Laboratory is the Free Computation Foundation's native computational research workspace: a minimal, high-performance environment for code, notebooks, research, Git, GitHub, AI-assisted work, external computation engines, experiments, and reproducible technical artifacts.

## North star

**Show the work, not the machinery.**

FCF-Laboratory should feel quiet, precise, and unusually dense with capability. The default surface is intentionally sparse. Tools appear when summoned, then get out of the way.

## Platform contract

- macOS: Apple Silicon (`arm64`) only.
- Linux: `x86_64` and `arm64`.
- Windows: `x86_64` initially.
- The shared core must remain OS- and architecture-agnostic.
- FCF-Laboratory is a native standalone application, never a browser application or Electron shell.

## Architecture

- `apps/` contains native platform applications.
- `packages/` contains portable implementation packages.
- `protocols/` contains stable contracts between Laboratory and external systems.
- `integrations/` contains adapters and provider-specific integration code, not vendored engines.
- `docs/` contains architecture, design, performance, and decision records.
- `.github/` contains repository automation only.

CENTL, CBX, and future computation engines remain independent repositories. Laboratory discovers, installs, connects to, and invokes them through the FCF Engine Protocol.

See `docs/architecture/FOUNDATION.md` and `docs/design/DESIGN-LANGUAGE.md` before adding major features.
