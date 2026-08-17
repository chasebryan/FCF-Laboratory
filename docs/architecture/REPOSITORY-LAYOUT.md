# Repository Layout

FCF-Laboratory keeps the repository root intentionally sparse.

## Root policy

A file belongs at root only when repository tooling, source-control conventions, or first-entry human navigation materially benefit from it being there.

Expected root entries are limited to essentials such as:

- `README.md`
- `LICENSE`
- `.gitignore`
- top-level directories

Build manifests should live inside the subsystem they govern whenever practical. For example, the Rust workspace manifest lives under `packages/rust/` and the macOS Swift package under `apps/macos/`.

## Directory responsibilities

- `apps/`: native platform applications
- `packages/`: portable implementation packages
- `protocols/`: versioned cross-boundary contracts
- `integrations/`: provider and external-engine adapters
- `docs/`: architecture, design, decisions, performance, development documentation
- `tests/`: future cross-system and acceptance fixtures that do not naturally belong beside a package
- `tools/`: repository development, packaging, and release tooling
- `.github/`: GitHub-specific automation and metadata

## Anti-patterns

Do not create root-level scratch scripts, research notes, generated artifacts, temporary output, ad-hoc test files, or one-off configuration files.

Do not create generic `misc`, `stuff`, `temp`, or `other` directories. If an artifact has no obvious home, fix the taxonomy before adding the artifact.
