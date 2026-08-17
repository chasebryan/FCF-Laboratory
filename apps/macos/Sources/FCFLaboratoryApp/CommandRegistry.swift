import Foundation

struct LaboratoryCommand: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let shortcut: String?
    let keywords: [String]

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        shortcut: String? = nil,
        keywords: [String] = []
    ) {
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
        LaboratoryCommand(
            id: "project.open",
            title: "Open Project",
            subtitle: "Open a local workspace",
            shortcut: "⌘O",
            keywords: ["workspace", "folder", "repository"]
        ),
        LaboratoryCommand(
            id: "document.save",
            title: "Save Active Document",
            subtitle: "Write the active editable object to disk",
            shortcut: "⌘S",
            keywords: ["file", "editor", "write"]
        ),
        LaboratoryCommand(
            id: "navigator.toggle",
            title: "Toggle Navigator",
            subtitle: "Reveal or hide project navigation",
            shortcut: "⌘B",
            keywords: ["sidebar", "files", "project"]
        ),
        LaboratoryCommand(
            id: "git.status",
            title: "Show Git Status",
            subtitle: "Inspect the active repository",
            keywords: ["repository", "branch", "changes"]
        ),
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
