# ADR 0012: Native notebook and append-only execution evidence

Status: accepted

## Context

FCF-Laboratory needs a notebook that can mix research prose, code, external mathematical engines, and AI while remaining inspectable, portable, and reproducible. Treating a notebook as a UI-only document would make execution state opaque. Treating the latest output as the cell's state would destroy historical evidence whenever a cell is rerun.

## Decision

Laboratory defines `FCF-NOTEBOOK-v1` and the `.fcfnb` file extension.

A notebook is a diffable JSON document with ordered cells. Cells contain authored source. Executable cells name a target. Each execution appends a separate execution record containing captured output, status, timestamps, and provenance.

The initial native targets are:

- local Python
- local shell
- external engine identifiers, including CENTL and CBX
- provider-independent AI

Engine code is never copied into the Laboratory repository. Engine cells send input to discovered external executables. AI cells pass through the FCF AI permission/provider boundary.

Execution is asynchronous. Captured output is bounded. The editor and notebook UI must remain usable during execution.

## Consequences

- notebook source and execution history can be reviewed in Git
- rerunning a cell never silently rewrites prior evidence
- the same notebook can be opened on another OS even when its original execution environment is unavailable
- replay resolves current providers and engines rather than trusting historical absolute paths
- provenance becomes a first-class scientific object rather than UI decoration

## Non-goals

`FCF-NOTEBOOK-v1` does not attempt byte-for-byte Jupyter compatibility. Jupyter import/export can be added as an adapter without defining the native object model.
