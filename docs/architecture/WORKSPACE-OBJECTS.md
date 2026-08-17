# Workspace Objects

FCF-Laboratory treats the workspace as a graph of technical objects rather than a file browser with extra panels.

Initial object kinds include:

- source
- notebook
- document
- paper
- dataset
- experiment
- terminal
- Git diff
- GitHub issue
- GitHub pull request
- AI session
- engine result
- witness
- graph

An object may have a portable workspace-relative path, but not every object must map to a file. Remote GitHub objects, ephemeral terminals, and derived engine results are examples.

The UI should be able to open these objects through one common tab/object surface. Object-specific capabilities are discovered contextually rather than by forcing the user into application-wide modes.
