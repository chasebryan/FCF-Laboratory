# macOS Application

The macOS application is the reference FCF-Laboratory user experience.

## Target

- Apple Silicon (`arm64`) only
- macOS 15 or newer
- native SwiftUI/AppKit application architecture

Intel macOS is intentionally unsupported.

## Product character

The Mac shell should remain sparse, native, and content-first. Shared capability belongs behind commands and contextual object actions rather than permanent control surfaces.

The current package is the first executable shell, not the final distribution format. Signing, notarization, app-bundle packaging, update delivery, and deeper AppKit editor surfaces will be added as dedicated subsystems rather than mixed into the initial workspace view.
