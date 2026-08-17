# ADR 0013: Native PTY terminal with portable session contract

Status: accepted

## Context

FCF-Laboratory needs an interactive terminal suitable for normal project work. A captured `Process` invocation is not a terminal: it lacks a pseudoterminal, interactive shell state, terminal dimensions, job-control behavior, and byte-stream input.

At the same time, platform PTY APIs differ. Darwin exposes PTY facilities such as `forkpty`; Linux has its own PTY implementation details; Windows provides ConPTY. Those differences must not leak into the portable core.

## Decision

Laboratory defines `FCF-TERMINAL-v1`, a portable terminal session specification and event vocabulary.

The macOS application uses a small native C bridge to Darwin `forkpty`, wrapped by a Swift `TerminalSession`. AppKit owns keyboard input and transcript rendering. Terminal resize events update the PTY window size. Multiple terminal workspace objects may exist simultaneously.

Terminal sessions are ephemeral. Closing a terminal tab or changing projects closes its PTY. Transcript memory is bounded. Terminal output is not automatically treated as reproducible research evidence.

Batch tasks remain a separate abstraction. Reproducible command execution belongs in notebook execution records, not implicit terminal history.

## Consequences

- the macOS terminal is genuinely interactive
- shared Rust code remains free of Darwin assumptions
- Linux and Windows can implement the same session contract with native facilities
- terminal lifecycle follows workspace-object lifecycle
- Laboratory can later replace or deepen the terminal screen emulator without changing the PTY/session contract
