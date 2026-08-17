# Engine Integrations

This directory contains adapters and manifests for external computational instruments.

## Rules

- Do not vendor engine repositories here.
- Do not copy CENTL or CBX source into FCF-Laboratory.
- Prefer stable machine-readable interfaces exposed by the engine.
- Record engine repository, version, executable identity, and transport in provenance.
- Keep platform-specific discovery inside the adapter boundary.

An engine integration may eventually contain:

```text
<engine>/
├── manifest.toml
├── adapter/
├── capabilities.toml
└── README.md
```

The first planned FCF instruments are CENTL and CBX, connected from their own repositories and installations.
