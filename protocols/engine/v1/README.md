# FCF Engine Protocol v1

**Protocol identifier:** `FCF-ENGINE-v1`

The FCF Engine Protocol is the boundary between FCF-Laboratory and external computational instruments.

## Goals

- Keep engines independent from the Laboratory source tree.
- Describe capabilities before execution.
- Support local, remote, container, and user-specified executable transports.
- Preserve exact engine identity and version in provenance.
- Permit engines to be unavailable without degrading the Laboratory application itself.
- Keep requests and responses serializable and transport-neutral.

## Required concepts

An engine adapter must be able to expose:

- identity
- protocol version
- engine version when known
- capabilities
- available execution transports
- readiness/status
- operation invocation
- cancellation where supported
- structured result
- provenance

## Initial operations

The v1 vocabulary reserves these operation names:

- `describe`
- `capabilities`
- `status`
- `execute`
- `verify`
- `cancel`

Engine-specific operations may use namespaced identifiers such as `centl.evaluate` or `cbx.search`.

## Repository boundary

`integrations/engines/<engine>/` may contain a manifest, adapter, capability mapping, and documentation. It must not contain a vendored copy of the engine repository.
