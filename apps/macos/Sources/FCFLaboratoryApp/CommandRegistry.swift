import Foundation

struct LaboratoryCommand: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let keywords: [String]

    init(id: String, title: String, subtitle: String? = nil, shortcut: String? = nil, keywords: [String] = []) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.shortcut = shortcut
        self.keywords = keywords
    }
}

struct CommandRegistry {
    let commands: [LaboratoryCommand]

    static let foundation = CommandRegistry(commands: [
        LaboratoryCommand(id: "project.open", title: "Open Project", subtitle: "Open a local workspace", shortcut: "⌘O", keywords: ["workspace", "folder", "repository"]),
        LaboratoryCommand(id: "notebook.new", title: "New FCF Notebook", subtitle: "Create a native reproducible research notebook", shortcut: "⌥⌘N", keywords: ["notebook", "experiment", "cells", "research", "provenance"]),
        LaboratoryCommand(id: "project.quickOpen", title: "Quick Open", subtitle: "Open an indexed project file", shortcut: "⌘P", keywords: ["file", "path", "open", "navigate"]),
        LaboratoryCommand(id: "project.search", title: "Search Project", subtitle: "Search text across indexed project files", shortcut: "⇧⌘F", keywords: ["find", "grep", "workspace", "files"]),
        LaboratoryCommand(id: "document.symbols", title: "Document Symbols", subtitle: "Navigate local symbols in the active document", shortcut: "⇧⌘O", keywords: ["outline", "function", "class", "struct", "method"]),
        LaboratoryCommand(id: "document.save", title: "Save Active Document", subtitle: "Write the active editable object to disk", shortcut: "⌘S", keywords: ["file", "editor", "write", "notebook"]),
        LaboratoryCommand(id: "navigator.toggle", title: "Toggle Navigator", subtitle: "Reveal or hide project navigation", shortcut: "⌘B", keywords: ["sidebar", "files", "project"]),
        LaboratoryCommand(id: "tasks.show", title: "Show Tasks", subtitle: "Run detected build and test tasks", keywords: ["build", "test", "cargo", "swift", "pytest", "run"]),
        LaboratoryCommand(id: "git.status", title: "Show Git Changes", subtitle: "Inspect the active repository working tree and diffs", keywords: ["repository", "branch", "changes", "diff", "github"]),
    ])

    func matches(_ query: String) -> [LaboratoryCommand] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return commands }
        return commands.filter { command in
            ([command.title, command.subtitle ?? ""] + command.keywords)
                .joined(separator: " ")
                .lowercased()
                .contains(normalized)
        }
    }
}
