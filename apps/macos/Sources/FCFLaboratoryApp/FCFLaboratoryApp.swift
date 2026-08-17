#if !arch(arm64)
#error("FCF-Laboratory for macOS supports Apple Silicon (arm64) only.")
#endif

import AppKit
import SwiftUI

@main
struct FCFLaboratoryApp: App {
    @StateObject private var model = LaboratoryModel()

    var body: some Scene {
        WindowGroup {
            WorkspaceView().environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Laboratory") {
                Button("Command Palette…") { model.isCommandPalettePresented.toggle() }
                    .keyboardShortcut("k", modifiers: [.command])
                Button("Quick Open…") { model.utilityPanel = .quickOpen }
                    .keyboardShortcut("p", modifiers: [.command])
                    .disabled(model.session.projectURL == nil)
                Button("Toggle Navigator") { model.isNavigatorPresented.toggle() }
                    .keyboardShortcut("b", modifiers: [.command])
                Button("Search Project…") { model.utilityPanel = .search }
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                    .disabled(model.session.projectURL == nil)
                Button("Document Symbols…") { model.utilityPanel = .symbols }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                    .disabled(model.activeEditorDocument == nil)

                Divider()

                Button("AI Workspace…") { model.utilityPanel = .ai }
                    .keyboardShortcut("a", modifiers: [.command, .option])
                    .disabled(model.session.projectURL == nil)
                Button("GitHub…") { model.utilityPanel = .github }
                    .keyboardShortcut("g", modifiers: [.command, .option])
                    .disabled(model.session.projectURL == nil)

                Divider()

                Button("New Notebook") { model.pendingAction = .newNotebook }
                    .keyboardShortcut("n", modifiers: [.command, .option])
                    .disabled(model.session.projectURL == nil)
                Button("New Terminal") { model.pendingAction = .newTerminal }
                    .keyboardShortcut("t", modifiers: [.command, .option])
                    .disabled(model.session.projectURL == nil)

                Divider()

                Button("Open Project…") { model.pendingAction = .openProject }
                    .keyboardShortcut("o", modifiers: [.command])
                Button("Save") { model.pendingAction = .saveActiveDocument }
                    .keyboardShortcut("s", modifiers: [.command])
                    .disabled(model.activeEditorDocument == nil && model.activeNotebookDocument == nil)
            }
        }
    }
}

@MainActor
final class LaboratoryModel: ObservableObject {
    enum PendingAction: Equatable { case openProject, newNotebook, newTerminal, showGitStatus, saveActiveDocument }
    enum UtilityPanel: Equatable { case quickOpen, search, symbols, tasks, git, github, ai }

    @Published var isCommandPalettePresented = false
    @Published var isNavigatorPresented = false
    @Published var pendingAction: PendingAction?
    @Published var utilityPanel: UtilityPanel?
    @Published var gitSnapshot: GitSnapshot?
    @Published var gitWorkspaceState: GitWorkspaceState?
    @Published var githubRemote: GitHubRemoteIdentity?
    @Published var session = WorkspaceSession()
    @Published private(set) var projectEntries: [ProjectEntry] = []
    @Published private(set) var expandedDirectoryPaths: Set<String> = []
    @Published private(set) var isIndexingProject = false
    @Published private(set) var editorDocuments: [URL: EditorDocument] = [:]
    @Published private(set) var notebookDocuments: [URL: NotebookDocument] = [:]
    @Published private(set) var terminalSessions: [LaboratoryObject.ID: TerminalSession] = [:]
    @Published private(set) var projectSearchResults: [ProjectSearchResult] = []
    @Published private(set) var isSearchingProject = false
    @Published private(set) var availableTasks: [LaboratoryTaskDescriptor] = []
    @Published private(set) var runningTaskID: String?
    @Published private(set) var lastTaskResult: LaboratoryTaskResult?
    @Published private(set) var resolvedLanguageServer: ResolvedLanguageServer?
    @Published private(set) var selectedGitChangeID: GitChange.ID?
    @Published private(set) var gitDiffText = ""
    @Published private(set) var isLoadingGitDiff = false

    let commands = CommandRegistry.foundation
    let githubWorkspace = GitHubWorkspaceController()
    let aiWorkspace = AIWorkspaceController()
    private var searchTask: Task<Void, Never>?

    init() {
        githubWorkspace.auth.refresh()
    }

    var activeObjectTitle: String { session.activeObject?.title ?? "FCF Laboratory" }
    var activeEditorDocument: EditorDocument? {
        guard let url = session.activeObject?.url else { return nil }
        return editorDocuments[url.standardizedFileURL]
    }
    var activeNotebookDocument: NotebookDocument? {
        guard let url = session.activeObject?.url else { return nil }
        return notebookDocuments[url.standardizedFileURL]
    }
    var activeTerminalSession: TerminalSession? {
        guard let id = session.activeObjectID else { return nil }
        return terminalSessions[id]
    }
    var notebookAIExecutor: (any NotebookAIExecuting)? { aiWorkspace }

    var aiContextSnapshot: AIWorkspaceContextSnapshot {
        let policy = aiWorkspace.policy
        let document = policy.activeDocument ? bounded(activeEditorDocument?.text, limit: 180_000) : nil
        let notebook: String?
        if policy.activeNotebook, let active = activeNotebookDocument {
            let source = active.notebook.cells.map { cell in "[\(cell.kind.rawValue)]\n\(cell.source)" }.joined(separator: "\n\n")
            notebook = bounded(source, limit: 180_000)
        } else { notebook = nil }
        let terminal = policy.terminalTranscript ? bounded(activeTerminalSession?.output, limit: 120_000, fromEnd: true) : nil
        return AIWorkspaceContextSnapshot(activeDocument: document, activeNotebook: notebook, terminalTranscript: terminal)
    }

    var visibleProjectEntries: [ProjectEntry] {
        guard let root = session.projectURL?.standardizedFileURL else { return [] }
        let rootPath = root.path
        return projectEntries.filter { entry in
            var parent = entry.url.deletingLastPathComponent().standardizedFileURL
            while parent.path != rootPath {
                guard expandedDirectoryPaths.contains(parent.path) else { return false }
                let next = parent.deletingLastPathComponent().standardizedFileURL
                guard next.path != parent.path else { return false }
                parent = next
            }
            return true
        }
    }

    func openProject(_ url: URL) {
        let dirtyEditors = editorDocuments.values.filter(\.isDirty)
        let dirtyNotebooks = notebookDocuments.values.filter(\.isDirty)
        let dirtyCount = dirtyEditors.count + dirtyNotebooks.count
        guard dirtyCount > 0 else { performOpenProject(url); return }

        let alert = NSAlert()
        alert.messageText = "Save changes before opening another project?"
        alert.informativeText = "There are \(dirtyCount) unsaved object\(dirtyCount == 1 ? "" : "s")."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save All"); alert.addButton(withTitle: "Discard Changes"); alert.addButton(withTitle: "Cancel")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task {
                for document in dirtyEditors { await document.save(); guard !document.isDirty else { return } }
                for notebook in dirtyNotebooks { await notebook.save(); guard !notebook.isDirty else { return } }
                performOpenProject(url)
            }
        case .alertSecondButtonReturn: performOpenProject(url)
        default: break
        }
    }

    private func performOpenProject(_ url: URL) {
        terminalSessions.values.forEach { $0.stop() }
        terminalSessions = [:]
        session.openProject(url)
        aiWorkspace.openProject(url)
        githubWorkspace.auth.refresh()
        isNavigatorPresented = true
        gitSnapshot = nil; gitWorkspaceState = nil; githubRemote = nil; gitDiffText = ""; selectedGitChangeID = nil
        projectEntries = []; expandedDirectoryPaths = []; projectSearchResults = []; editorDocuments = [:]; notebookDocuments = [:]
        resolvedLanguageServer = nil; availableTasks = FoundationTaskDiscovery.tasks(for: url); lastTaskResult = nil; isIndexingProject = true

        Task {
            async let git = GitRepository.snapshot(at: url)
            async let richGit = GitWorkspaceService.state(at: url)
            async let github = GitHubRemoteService.detect(at: url)
            async let entries = ProjectIndexer.discover(at: url)
            gitSnapshot = await git
            gitWorkspaceState = await richGit
            githubRemote = await github
            projectEntries = await entries
            isIndexingProject = false
            githubWorkspace.refresh(remote: githubRemote)
        }
    }

    func toggleDirectory(_ url: URL) {
        let path = url.standardizedFileURL.path
        if expandedDirectoryPaths.contains(path) { expandedDirectoryPaths.remove(path) } else { expandedDirectoryPaths.insert(path) }
    }

    func createNotebook() {
        guard let projectURL = session.projectURL else { return }
        let target = uniqueNotebookURL(in: projectURL); let title = target.deletingPathExtension().lastPathComponent
        Task {
            do { try await NotebookDocument.create(at: target, title: title); openFile(target); projectEntries = await ProjectIndexer.discover(at: projectURL) }
            catch { showError(title: "Unable to create notebook", message: error.localizedDescription) }
        }
    }

    func createTerminal() {
        guard let projectURL = session.projectURL else { return }
        let index = terminalSessions.count + 1; let title = index == 1 ? "Terminal" : "Terminal \(index)"
        let object = LaboratoryObject(title: title, kind: .terminal); session.openObject(object)
        let terminal = TerminalSession(id: object.id, title: title, workingDirectory: projectURL)
        terminalSessions[object.id] = terminal; terminal.start(); resolvedLanguageServer = nil
    }

    func openFile(_ url: URL, line: Int? = nil) {
        let standardized = url.standardizedFileURL; let kind = objectKind(for: standardized)
        let object = LaboratoryObject(title: standardized.lastPathComponent, kind: kind, url: standardized); session.openObject(object)
        if kind == .notebook, standardized.pathExtension.lowercased() == "fcfnb" {
            if notebookDocuments[standardized] == nil { let notebook = NotebookDocument(url: standardized); notebookDocuments[standardized] = notebook; Task { await notebook.load() } }
            resolvedLanguageServer = nil; return
        }
        guard isTextEditable(standardized) else { return }
        let document: EditorDocument
        if let existing = editorDocuments[standardized] { document = existing; Task { resolvedLanguageServer = await LanguageServerDiscovery.resolve(for: document.language.id) } }
        else { document = EditorDocument(url: standardized); editorDocuments[standardized] = document; Task { await document.load(); resolvedLanguageServer = await LanguageServerDiscovery.resolve(for: document.language.id) } }
        if let line { document.requestJump(to: line) }
    }

    func requestCloseObject(_ id: LaboratoryObject.ID) {
        guard let object = session.objects.first(where: { $0.id == id }) else { return }
        if let terminal = terminalSessions[id] { terminal.stop(); closeObject(id, url: nil); return }
        guard let url = object.url?.standardizedFileURL else { closeObject(id, url: nil); return }
        if let document = editorDocuments[url], document.isDirty { promptToCloseEditor(document, object: object, url: url); return }
        if let notebook = notebookDocuments[url], notebook.isDirty { promptToCloseNotebook(notebook, object: object, url: url); return }
        closeObject(id, url: url)
    }

    private func promptToCloseEditor(_ document: EditorDocument, object: LaboratoryObject, url: URL) {
        let alert = closeAlert(for: object.title)
        switch alert.runModal() {
        case .alertFirstButtonReturn: Task { await document.save(); guard !document.isDirty else { return }; closeObject(object.id, url: url) }
        case .alertSecondButtonReturn: closeObject(object.id, url: url)
        default: break
        }
    }
    private func promptToCloseNotebook(_ notebook: NotebookDocument, object: LaboratoryObject, url: URL) {
        let alert = closeAlert(for: object.title)
        switch alert.runModal() {
        case .alertFirstButtonReturn: Task { await notebook.save(); guard !notebook.isDirty else { return }; closeObject(object.id, url: url) }
        case .alertSecondButtonReturn: closeObject(object.id, url: url)
        default: break
        }
    }
    private func closeAlert(for title: String) -> NSAlert {
        let alert = NSAlert(); alert.messageText = "Save changes to \(title)?"; alert.informativeText = "Your changes will be lost if you close this object without saving."; alert.alertStyle = .warning
        alert.addButton(withTitle: "Save"); alert.addButton(withTitle: "Don’t Save"); alert.addButton(withTitle: "Cancel"); return alert
    }
    private func closeObject(_ id: LaboratoryObject.ID, url: URL?) {
        terminalSessions.removeValue(forKey: id)?.stop(); session.closeObject(id)
        if let url { let standardized = url.standardizedFileURL; editorDocuments.removeValue(forKey: standardized); notebookDocuments.removeValue(forKey: standardized) }
    }

    func saveActiveDocument() {
        if let document = activeEditorDocument { Task { await document.save() } }
        else if let notebook = activeNotebookDocument { Task { await notebook.save() } }
    }

    func searchProject(_ query: String) {
        searchTask?.cancel(); let entries = projectEntries; let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { projectSearchResults = []; isSearchingProject = false; return }
        isSearchingProject = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120)); guard !Task.isCancelled else { return }
            let results = await ProjectSearch.search(query: trimmed, entries: entries)
            guard !Task.isCancelled, let self else { return }; self.projectSearchResults = results; self.isSearchingProject = false
        }
    }

    func showSymbol(_ symbol: DocumentSymbol) { activeEditorDocument?.requestJump(to: symbol.line); utilityPanel = nil }
    func runTask(_ descriptor: LaboratoryTaskDescriptor) {
        guard let projectURL = session.projectURL, runningTaskID == nil else { return }
        runningTaskID = descriptor.id; lastTaskResult = nil
        Task { let result = await LaboratoryTaskRunner.run(descriptor, in: projectURL); lastTaskResult = result; runningTaskID = nil; gitSnapshot = await GitRepository.snapshot(at: projectURL); gitWorkspaceState = await GitWorkspaceService.state(at: projectURL) }
    }
    func refreshGitWorkspace() {
        guard let projectURL = session.projectURL else { return }
        Task { gitSnapshot = await GitRepository.snapshot(at: projectURL); gitWorkspaceState = await GitWorkspaceService.state(at: projectURL); githubRemote = await GitHubRemoteService.detect(at: projectURL); githubWorkspace.refresh(remote: githubRemote) }
    }
    func loadGitDiff(_ change: GitChange) {
        guard let projectURL = session.projectURL else { return }
        selectedGitChangeID = change.id; gitDiffText = ""; isLoadingGitDiff = true
        Task {
            let text: String
            if change.state == .untracked { text = "Untracked file. No Git diff exists until the file is added." }
            else { let loaded = await GitWorkspaceService.diff(path: change.path, staged: change.staged, at: projectURL); text = loaded.isEmpty ? "No diff available for this change." : loaded }
            guard selectedGitChangeID == change.id else { return }; gitDiffText = text; isLoadingGitDiff = false
        }
    }

    private func uniqueNotebookURL(in projectURL: URL) -> URL {
        var index = 1
        while true { let name = index == 1 ? "Notebook.fcfnb" : "Notebook \(index).fcfnb"; let candidate = projectURL.appendingPathComponent(name); if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }; index += 1 }
    }
    private func objectKind(for url: URL) -> LaboratoryObject.Kind {
        switch url.pathExtension.lowercased() { case "md", "txt", "rst": return .document; case "pdf": return .paper; case "fcfnb", "ipynb": return .notebook; case "csv", "tsv", "json", "jsonl": return .dataset; default: return .source }
    }
    private func isTextEditable(_ url: URL) -> Bool {
        let binary: Set<String> = ["fcfnb", "pdf", "png", "jpg", "jpeg", "gif", "webp", "ico", "zip", "gz", "xz", "bz2", "dmg", "pkg", "app", "exe", "dll", "so", "dylib", "a", "o", "class", "jar"]
        return !binary.contains(url.pathExtension.lowercased())
    }
    private func bounded(_ value: String?, limit: Int, fromEnd: Bool = false) -> String? {
        guard let value, !value.isEmpty else { return nil }
        if value.count <= limit { return value }
        return fromEnd ? String(value.suffix(limit)) : String(value.prefix(limit))
    }
    private func showError(title: String, message: String) {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = message; alert.alertStyle = .warning; alert.runModal()
    }
}
