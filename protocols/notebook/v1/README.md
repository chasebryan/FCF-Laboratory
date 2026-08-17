# FCF Notebook Protocol v1

`FCF-NOTEBOOK-v1` is the portable, diffable notebook format used by FCF-Laboratory. Native notebook files use the `.fcfnb` extension and are UTF-8 JSON.

## Core law

**Cells are content. Executions are evidence.** Editing a cell changes its source but does not rewrite prior execution records. A new run appends a new execution record.

## Notebook

A notebook contains:

- `schema_version`: exactly `FCF-NOTEBOOK-v1`
- `id`: stable notebook identity
- `title`
- `metadata`: string key/value metadata
- `cells`: ordered cell list

## Cells

Cell kinds are:

- `markdown`: non-executable research prose
- `code`: executable local code, initially Python or shell
- `engine`: input dispatched to an external FCF instrument such as CENTL or CBX
- `ai`: input dispatched through the provider-independent FCF AI boundary

Executable cells carry an execution target. Markdown cells do not.

## Execution records

Each run appends a record containing:

- stable execution id
- start and finish timestamps
- status
- the resolved execution target
- captured stdout and stderr
- provenance

Provenance contains the SHA-256 digest of the exact cell source, working directory, provider identity, resolved command, host OS, and host architecture. Output capture is bounded by the native client to protect workspace responsiveness.

## Portability

Notebook files must not require absolute machine paths for scientific interpretation. Absolute working-directory values may appear inside historical execution evidence, because they describe where a run occurred; they are evidence, not instructions for replay. Replay must resolve the current workspace and current engine installation independently.

## Engines

Engine cells never vendor CENTL, CBX, or another engine. The cell names an engine identifier and Laboratory resolves it through the engine integration layer. Missing engines produce failed execution evidence rather than corrupting the notebook.

## AI

AI cells name an AI provider identifier. Workspace context is not implicitly attached. Context access is governed separately by the AI permission boundary.
