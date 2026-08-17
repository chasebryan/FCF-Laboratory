import Foundation

enum LanguageID: String, CaseIterable, Codable, Sendable {
    case swift
    case rust
    case python
    case c
    case cpp
    case objectiveC = "objective-c"
    case javascript
    case typescript
    case json
    case toml
    case yaml
    case markdown
    case shell
    case ocaml
    case centl
    case plainText = "plain-text"
}

struct LanguageProfile: Hashable, Sendable {
    let id: LanguageID
    let displayName: String
    let lspIdentifier: String?
    let lineComment: String?

    static func detect(url: URL, contentPrefix: String = "") -> LanguageProfile {
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()

        if name == "cargo.toml" || name == "pyproject.toml" { return profile(.toml) }
        if name == "makefile" { return profile(.plainText) }
        if contentPrefix.hasPrefix("#!") && contentPrefix.contains("python") { return profile(.python) }
        if contentPrefix.hasPrefix("#!") && (contentPrefix.contains("bash") || contentPrefix.contains("zsh") || contentPrefix.contains("sh")) { return profile(.shell) }

        switch ext {
        case "swift": return profile(.swift)
        case "rs": return profile(.rust)
        case "py", "pyi": return profile(.python)
        case "c", "h": return profile(.c)
        case "cc", "cpp", "cxx", "hpp", "hh": return profile(.cpp)
        case "m", "mm": return profile(.objectiveC)
        case "js", "mjs", "cjs": return profile(.javascript)
        case "ts", "tsx": return profile(.typescript)
        case "json", "jsonl": return profile(.json)
        case "toml": return profile(.toml)
        case "yaml", "yml": return profile(.yaml)
        case "md", "markdown": return profile(.markdown)
        case "sh", "bash", "zsh": return profile(.shell)
        case "ml", "mli": return profile(.ocaml)
        case "centl": return profile(.centl)
        default: return profile(.plainText)
        }
    }

    static func profile(_ id: LanguageID) -> LanguageProfile {
        switch id {
        case .swift: return .init(id: id, displayName: "Swift", lspIdentifier: "swift", lineComment: "//")
        case .rust: return .init(id: id, displayName: "Rust", lspIdentifier: "rust", lineComment: "//")
        case .python: return .init(id: id, displayName: "Python", lspIdentifier: "python", lineComment: "#")
        case .c: return .init(id: id, displayName: "C", lspIdentifier: "c", lineComment: "//")
        case .cpp: return .init(id: id, displayName: "C++", lspIdentifier: "cpp", lineComment: "//")
        case .objectiveC: return .init(id: id, displayName: "Objective-C", lspIdentifier: "objective-c", lineComment: "//")
        case .javascript: return .init(id: id, displayName: "JavaScript", lspIdentifier: "javascript", lineComment: "//")
        case .typescript: return .init(id: id, displayName: "TypeScript", lspIdentifier: "typescript", lineComment: "//")
        case .json: return .init(id: id, displayName: "JSON", lspIdentifier: "json", lineComment: nil)
        case .toml: return .init(id: id, displayName: "TOML", lspIdentifier: "toml", lineComment: "#")
        case .yaml: return .init(id: id, displayName: "YAML", lspIdentifier: "yaml", lineComment: "#")
        case .markdown: return .init(id: id, displayName: "Markdown", lspIdentifier: "markdown", lineComment: nil)
        case .shell: return .init(id: id, displayName: "Shell", lspIdentifier: "shellscript", lineComment: "#")
        case .ocaml: return .init(id: id, displayName: "OCaml", lspIdentifier: "ocaml", lineComment: nil)
        case .centl: return .init(id: id, displayName: "CENTL", lspIdentifier: "centl", lineComment: nil)
        case .plainText: return .init(id: id, displayName: "Plain Text", lspIdentifier: nil, lineComment: nil)
        }
    }
}
