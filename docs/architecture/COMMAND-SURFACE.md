# Command Surface

The command surface is a primary mechanism for exposing capability without permanent visual clutter.

## Principles

- Commands are searchable.
- Commands are contextual to the active workspace object and selection.
- Keyboard use is first-class.
- Common operations remain discoverable without memorizing shortcuts.
- Providers and engines contribute namespaced commands through explicit registration rather than arbitrary UI injection.

Examples:

```text
Project: Open
Git: Create Branch
GitHub: Open Pull Request
Notebook: Add Math Cell
Engine: Verify with CENTL
Engine: Search with CBX
AI: Ask ChatGPT About Selection
Experiment: Create from Selection
```

A selected equation, source symbol, Git diff, paper passage, or experiment may expose a different set of relevant commands without changing the entire application mode.
