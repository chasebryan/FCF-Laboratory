# FCF Terminal Protocol v1

`FCF-TERMINAL-v1` defines the portable session contract for interactive terminals in FCF-Laboratory. The protocol describes terminal intent and lifecycle; each platform supplies its native pseudoterminal implementation.

## Session specification

A session contains:

- protocol version
- stable session id
- working directory
- optional shell path
- initial rows and columns
- explicit environment overrides

## Events

Portable terminal events are output bytes, resize notifications, exit status, and failure information.

## Platform adapters

- macOS uses a native Darwin PTY (`forkpty`) behind the Swift/AppKit terminal surface.
- Linux will implement the same contract with its native PTY facilities.
- Windows will implement the same contract with ConPTY.

The portable Rust crates never call a platform PTY API directly.

## Tasks are not terminals

Laboratory tasks are bounded non-interactive jobs. A terminal is a long-lived interactive byte stream with terminal dimensions and shell state. The two surfaces share process-safety principles but are intentionally separate abstractions.

## Lifecycle

Terminal sessions are ephemeral workspace objects. Opening a terminal creates a native session. Closing its tab or changing projects closes the PTY and removes the session from Laboratory. Terminal transcript retention is bounded to prevent an unbounded shell from consuming application memory.

Terminal history is not scientific provenance by default. A user who needs reproducible command execution should use a notebook code or engine cell, which creates an execution record.
