# ADR 0005: Workspace shell

Status: Accepted

## Decision

FCF-Laboratory uses a content-first workspace shell. Projects contain workspace objects; the application surface renders one active object at a time and reveals navigation only when requested or when project context makes it useful.

The native shell owns:

- project opening and recent-project recall,
- object identity and tab selection,
- command discovery,
- lightweight repository awareness,
- native platform navigation behavior.

The shell does not own engine implementations, AI implementations, notebook kernels, or language runtimes.

## Interface laws

1. The work receives the majority of the window.
2. A navigator is hidden by default and is always dismissible.
3. A tab strip is absent when it has nothing useful to disambiguate.
4. Commands are discoverable through a searchable registry rather than permanent chrome.
5. Repository status is informational and quiet; Git must never block interaction.
6. Project opening must not wait for indexing, Git inspection, AI, or engines.
7. Recent-project state is application state, not workspace data, and must not leak machine-specific paths into portable project artifacts.

## Rationale

This preserves Laboratory's defining asymmetry: visible complexity remains small while available capability can grow substantially behind the command and object systems.
