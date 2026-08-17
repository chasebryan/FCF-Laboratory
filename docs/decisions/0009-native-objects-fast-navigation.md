# ADR 0009: Native Objects and Fast Navigation

Status: accepted

FCF-Laboratory opens common technical objects with native or purpose-built renderers and keeps navigation faster than visible project chrome.

## Decisions

- `⌘P` is Quick Open and filters the already discovered project file set locally.
- Project text search remains separate from Quick Open because filename navigation and content search have different latency and result semantics.
- PDF papers use PDFKit on macOS rather than a web renderer or embedded browser.
- Git changes are selectable and can expose their real Git diff inside the transient Git surface.
- A GitHub origin is identified from the repository remote locally. Detecting `owner/repository` does not imply authentication or grant network access.
- GitHub identity detection is groundwork for the later authenticated GitHub provider, not a substitute for it.
- Native object rendering must not force unsupported objects through the text editor.

## Boundary

Interactive terminal emulation, notebook execution semantics, authenticated GitHub operations, and authenticated OpenAI/ChatGPT operations each require their own architectural decisions. They are intentionally not guessed inside this foundation sweep.
