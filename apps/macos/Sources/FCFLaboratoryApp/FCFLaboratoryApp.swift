#if !arch(arm64)
#error("FCF-Laboratory for macOS supports Apple Silicon (arm64) only.")
#endif

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

                Button("Toggle Navigator") {
                    model.isNavigatorPresented.toggle()
                }
                .keyboardShortcut("b", modifiers: [.command])

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

    @Published var isCommandPalettePresented = false
    @Published var isNavigatorPresented = false
    @Published var pendingAction: PendingAction?
    @Published var gitSnapshot: GitSnapshot?
    @Published var session = WorkspaceSession()
    @Published private(set) var projectEntries: [ProjectEntry] = []
    @Published private(set) var isIndexingProject = false
    @Published private(set) var editorDocuments: [URL: EditorDocument] = [:]

    let commands = CommandRegistry.foundation

    var activeObjectTitle: String {
        session.activeObject?.title ?? "FCF Laboratory"
    }

    var activeEditorDocument: EditorDocument? {
        guard let url = session.activeObject?.url else { return nil }
        return editorDocuments[url.standardizedFileURL]
    }

    func openProject(_ url: URL) {
        session.openProject(url)
        isNavigatorPresented = true
        gitSnapshot = nil
        projectEntries = []
        editorDocuments = [:]
        isIndexingProject = true

        Task {
            async let git = GitRepository.snapshot(at: url)
            async let entries = ProjectIndexer.discover(at: url)
            gitSnapshot = await git
            projectEntries = await entries
            isIndexingProject = false
        }
    }

    func openFile(_ url: URL) {
        let standardized = url.standardizedFileURL
        let object = LaboratoryObject(
            title: standardized.lastPathComponent,
            kind: objectKind(for: standardized),
            url: standardized
        )
        session.openObject(object)

        guard isTextEditable(standardized) else { return }
        if editorDocuments[standardized] == nil {
            let document = EditorDocument(url: standardized)
            editorDocuments[standardized] = document
            Task { await document.load() }
        }
    }

    func saveActiveDocument() {
        guard let document = activeEditorDocument else { return }
        Task { await document.save() }
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
