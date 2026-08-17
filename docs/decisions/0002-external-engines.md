# ADR 0002: Engines remain external

## Status

Accepted.

## Decision

CENTL, CBX, and other computation engines remain independent repositories and installations. FCF-Laboratory integrates them through adapters and the FCF Engine Protocol.

No engine source tree should be migrated into this repository merely for convenience.

## Rationale

Engines have their own release cycles, dependencies, platform support, licenses, and research identities. Keeping them sovereign prevents FCF-Laboratory from becoming a monorepo of unrelated computational systems.

## Consequences

- `integrations/engines/` contains adapters and manifests, never vendored engine source.
- Engine availability is discovered at runtime.
- A missing or unsupported engine must not make FCF-Laboratory itself unsupported.
- Execution transports may include local executable, remote service, container, or user-specified binary.
- Engine provenance records the exact engine identity and version used for a result.
