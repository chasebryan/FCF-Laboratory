# ADR 0011: Project Scale and Document Safety

Status: accepted

FCF-Laboratory must remain organized and responsive when a project stops being small.

## Decisions

- Project discovery indexes deeply enough for real repositories instead of silently stopping at four directory levels.
- Hidden technical files are discoverable. `.github`, `.gitignore`, and similar project material must not disappear merely because the filesystem marks their names hidden.
- Known generated/dependency directories are excluded from the foundation index.
- The navigator is collapsed by default and expands directories explicitly, so a large index does not become visual clutter.
- Project indexing remains asynchronous and bounded by an entry ceiling.
- The v0 text editor refuses editable loading above 32 MB rather than risking a giant allocation and frozen UI. Larger-object support belongs to specialized renderers.
- Closing a dirty document prompts Save, Don’t Save, or Cancel.
- Opening another project while documents are dirty prompts Save All, Discard Changes, or Cancel.

Protecting user work and protecting interaction latency are both correctness properties.
