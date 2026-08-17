import Foundation

@MainActor
final class AIContextPolicy: ObservableObject {
    @Published var activeDocument: Bool { didSet { save() } }
    @Published var activeNotebook: Bool { didSet { save() } }
    @Published var terminalTranscript: Bool { didSet { save() } }
    @Published var projectFiles: Bool { didSet { save() } }
    @Published var gitDiff: Bool { didSet { save() } }

    private let defaults = UserDefaults.standard
    private let prefix = "FCFLaboratory.AIContext."

    init() {
        activeDocument = defaults.bool(forKey: prefix + "activeDocument")
        activeNotebook = defaults.bool(forKey: prefix + "activeNotebook")
        terminalTranscript = defaults.bool(forKey: prefix + "terminalTranscript")
        projectFiles = defaults.bool(forKey: prefix + "projectFiles")
        gitDiff = defaults.bool(forKey: prefix + "gitDiff")
    }

    func revokeAll() {
        activeDocument = false
        activeNotebook = false
        terminalTranscript = false
        projectFiles = false
        gitDiff = false
    }

    private func save() {
        defaults.set(activeDocument, forKey: prefix + "activeDocument")
        defaults.set(activeNotebook, forKey: prefix + "activeNotebook")
        defaults.set(terminalTranscript, forKey: prefix + "terminalTranscript")
        defaults.set(projectFiles, forKey: prefix + "projectFiles")
        defaults.set(gitDiff, forKey: prefix + "gitDiff")
    }
}

struct AIWorkspaceContextSnapshot: Sendable {
    var activeDocument: String?
    var activeNotebook: String?
    var terminalTranscript: String?

    static let empty = AIWorkspaceContextSnapshot(activeDocument: nil, activeNotebook: nil, terminalTranscript: nil)

    var preamble: String {
        var sections: [String] = []
        if let activeDocument, !activeDocument.isEmpty {
            sections.append("<active_document>\n\(activeDocument)\n</active_document>")
        }
        if let activeNotebook, !activeNotebook.isEmpty {
            sections.append("<active_notebook>\n\(activeNotebook)\n</active_notebook>")
        }
        if let terminalTranscript, !terminalTranscript.isEmpty {
            sections.append("<terminal_transcript>\n\(terminalTranscript)\n</terminal_transcript>")
        }
        return sections.joined(separator: "\n\n")
    }
}

struct AIContextGrantSnapshot: Sendable {
    let projectFiles: Bool
    let gitDiff: Bool
}
