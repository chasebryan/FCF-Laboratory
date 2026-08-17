# ADR 0008: Intelligence Surfaces Are Transient

Status: accepted

Search, symbols, tasks, Git state, and similar workspace intelligence appear through a shared transient utility surface rather than permanent IDE panels.

This preserves the FCF-Laboratory design rule that the work occupies the screen and machinery appears only when invoked.

## Rules

- Project search uses a transient panel and never requires a permanent search sidebar.
- Document symbols use the same surface and jump directly to the selected line.
- Build and test tasks use the same surface, with output contained there instead of permanently reserving a console region.
- Git working-tree state uses the same surface. Git remains first-class, but it does not own permanent chrome.
- The command palette is the primary discoverability layer for these capabilities.
- Keyboard shortcuts may invoke a surface directly when the action is common enough.
- Utility surfaces are dismissible with Escape and do not alter project files.
- Additional permanent panels require a new design decision.

The application may become more powerful without increasing default visible complexity.
