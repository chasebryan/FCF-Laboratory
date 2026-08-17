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
            WorkspaceView()
                .environmentObject(model)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Laboratory") {
                Button("Command Palette…") {
                    model.isCommandPalettePresented.toggle()
                }
                .keyboardShortcut("k", modifiers: [.command])

                Button("Quick Open…") {
                    model.utilityPanel = .quickOpen
                }
                .keyboardShortcut("p", modifiers: [.command])
                .disabled(model.session.projectURL == nil)

                Button("Toggle Navigator") {
                    model.isNavigatorPresented.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command])

                Button("Search Project…") {
                    model.utilityPanel = .search
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(model.session.projectURL == nil)

                Button("Document Symbols…") {
                    model.utilityPanel = .symbols
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
                .disabled(model.activeEditorDocument == nil)

                Divider()

                Button("Open Project…") {
                    model.pendingAction = .openProject
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("Save") {
                    model.pendingAction = .saveActiveDocument
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(model.activeEditorDocument == nil)
            }
        }
    }
}

@MainActor
final class LaboratoryModel: ObservableObject {
    enum PendingAction: Equatable {
        case openProject
        case showGitStatus
        case saveActiveDocument
    }

    enum UtilityPanel: Equatable {
        case quickOpen
        case search
        case symbols
        case tasks
        case git
    }

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
    private var searchTask: Task<Void, Never>?

    var activeObjectTitle: String {
        session.activeObject?.title ?? "FCF Laboratory"
    }

    var activeEditorDocument: EditorDocument? {
        guard let url = session.activeObject?.url else { return nil }
        return editorDocuments[url.standardizedFileURL]
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
        let dirty = editorDocuments.values.filter(\.isDirty)
        guard !dirty.isEmpty else {
            performOpenProject(url)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Save changes before opening another project?"
        alert.informativeText = "There are \(dirty.count) unsaved document\(dirty.count == 1 ? "" : "s")."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save All")
        alert.addButton(withTitle: "Discard Changes")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task {
                for document in dirty {
                    await document.save()
                    guard !document.isDirty else { return }
                }
                performOpenProject(url)
            }
        case .alertSecondButtonReturn:
            performOpenProject(url)
        default:
            break
        }
    }

    private func performOpenProject(_ url: URL) {
        session.openProject(url)
        isNavigatorPresented = true
        gitSnapshot = nil
        gitWorkspaceState = nil
        githubRemote = nil
        gitDiffText = ""
        selectedGitChangeID = nil
        projectEntries = []
        expandedDirectoryPaths = []
        projectSearchResults = []
        editorDocuments = [:]
        resolvedLanguageServer = nil
        availableTasks = FoundationTaskDiscovery.tasks(for: url)
        lastTaskResult = nil
        isIndexingProject = true

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
        }
    }

    func toggleDirectory(_ url: URL) {
        let path = url.standardizedFileURL.path
        if expandedDirectoryPaths.contains(path) {
            expandedDirectoryPaths.remove(path)
        } else {
            expandedDirectoryPaths.insert(path)
        }
    }

    func openFile(_ url: URL, line: Int? = nil) {
        let standardized = url.standardizedFileURL
        let object = LaboratoryObject(
            title: standardized.lastPathComponent,
            kind: objectKind(for: standardized),
            url: standardized
        )
        session.openObject(object)

        guard isTextEditable(standardized) else { return }
        let document: EditorDocument
        if let existing = editorDocuments[standardized] {
            document = existing
            Task {
                resolvedLanguageServer = await LanguageServerDiscovery.resolve(for: document.language.id)
            }
        } else {
            document = EditorDocument(url: standardized)
            editorDocuments[standardized] = document
            Task {
                await document.load()
                resolvedLanguageServer = await LanguageServerDiscovery.resolve(for: document.language.id)
            }
        }
        if let line { document.requestJump(to: line) }
    }

    func requestCloseObject(_ id: LaboratoryObject.ID) {
        guard let object = session.objects.first(where: { $0.id == id }) else { return }
        guard let url = object.url?.standardizedFileURL,
              let document = editorDocuments[url],
              document.isDirty else {
            closeObject(id, url: object.url)
            return
        }

        let alert = NSAlert()
        alert.messageText = "Save changes to \(object.title)?"
        alert.informativeText = "Your changes will be lost if you close this document without saving."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don’t Save")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            Task {
                await document.save()
                guard !document.isDirty else { return }
                closeObject(id, url: url)
            }
        case .alertSecondButtonReturn:
            closeObject(id, url: url)
        default:
            break
        }
    }

    private func closeObject(_ id: LaboratoryObject.ID, url: URL?) {
        session.closeObject(id)
        if let url {
            editorDocuments.removeValue(forKey: url.standardizedFileURL)
        }
    }

    func saveActiveDocument() {
        guard let document = activeEditorDocument else { return }
        Task { await document.save() }
    }

    func searchProject(_ query: String) {
        searchTask?.cancel()
        let entries = projectEntries
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            projectSearchResults = []
            isSearchingProject = false
            return
        }
        isSearchingProject = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            let results = await ProjectSearch.search(query: trimmed, entries: entries)
            guard !Task.isCancelled, let self else { return }
            self.projectSearchResults = results
            self.isSearchingProject = false
        }
    }

    func showSymbol(_ symbol: DocumentSymbol) {
        activeEditorDocument?.requestJump(to: symbol.line)
        utilityPanel = nil
    }

    func runTask(_ descriptor: LaboratoryTaskDescriptor) {
        guard let projectURL = session.projectURL, runningTaskID == nil else { return }
        runningTaskID = descriptor.id
        lastTaskResult = nil
        Task {
            let result = await LaboratoryTaskRunner.run(descriptor, in: projectURL)
            lastTaskResult = result
            runningTaskID = nil
            gitSnapshot = await GitRepository.snapshot(at: projectURL)
            gitWorkspaceState = await GitWorkspaceService.state(at: projectURL)
        }
    }

    func refreshGitWorkspace() {
        guard let projectURL = session.projectURL else { return }
        Task {
            gitSnapshot = await GitRepository.snapshot(at: projectURL)
            gitWorkspaceState = await GitWorkspaceService.state(at: projectURL)
            githubRemote = await GitHubRemoteService.detect(at: projectURL)
        }
    }

    func loadGitDiff(_ change: GitChange) {
        guard let projectURL = session.projectURL else { return }
        selectedGitChangeID = change.id
        gitDiffText = ""
        isLoadingGitDiff = true
        Task {
            let text: String
            if change.state == .untracked {
                text = "Untracked file. No Git diff exists until the file is added."
            } else {
                let loaded = await GitWorkspaceService.diff(path: change.path, staged: change.staged, at: projectURL)
                text = loaded.isEmpty ? "No diff available for this change." : loaded
            }
            guard selectedGitChangeID == change.id else { return }
            gitDiffText = text
            isLoadingGitDiff = false
        }
    }

    private func objectKind(for url: URL) -> LaboratoryObject.Kind {
        switch url.pathExtension.lowercased() {
        case "md", "txt", "rst": return .document
        case "pdf": return .paper
        case "ipynb": return .notebook
        case "csv", "tsv", "json", "jsonl": return .dataset
        default: return .source
        }
    }

    private func isTextEditable(_ url: URL) -> Bool {
        let binaryExtensions: Set<String> = [
            "pdf", "png", "jpg", "jpeg", "gif", "webp", "ico", "zip", "gz", "xz", "bz2",
            "dmg", "pkg", "app", "exe", "dll", "so", "dylib", "a", "o", "class", "jar"
        ]
        return !binaryExtensions.contains(url.pathExtension.lowercased())
    }
}
