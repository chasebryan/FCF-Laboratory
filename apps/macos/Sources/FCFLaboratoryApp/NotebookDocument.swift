import Foundation

let fcfNotebookSchemaVersion = "FCF-NOTEBOOK-v1"

enum NotebookCellKind: String, Codable, CaseIterable, Sendable {
    case markdown
    case code
    case engine
    case ai
}

enum NotebookTargetKind: String, Codable, CaseIterable, Sendable {
    case python
    case shell
    case engine
    case ai
}

struct NotebookExecutionTarget: Codable, Hashable, Sendable {
    var kind: NotebookTargetKind
    var identifier: String?

    static let python = NotebookExecutionTarget(kind: .python, identifier: "python3")
    static let shell = NotebookExecutionTarget(kind: .shell, identifier: "zsh")
    static let centl = NotebookExecutionTarget(kind: .engine, identifier: "centl")
    static let cbx = NotebookExecutionTarget(kind: .engine, identifier: "cbx")
    static let openAI = NotebookExecutionTarget(kind: .ai, identifier: "openai")

    var displayName: String {
        switch kind {
        case .python: return "Python"
        case .shell: return "Shell"
        case .engine: return identifier?.uppercased() ?? "Engine"
        case .ai: return identifier == "openai" ? "OpenAI" : (identifier ?? "AI")
        }
    }
}

enum NotebookExecutionStatus: String, Codable, Sendable {
    case succeeded
    case failed
    case cancelled
}

struct NotebookExecutionProvenance: Codable, Hashable, Sendable {
    var sourceDigest: String
    var workingDirectory: String
    var provider: String
    var command: [String]
    var hostOS: String
    var hostArch: String

    enum CodingKeys: String, CodingKey {
        case sourceDigest = "source_digest"
        case workingDirectory = "working_directory"
        case provider
        case command
        case hostOS = "host_os"
        case hostArch = "host_arch"
    }
}

struct NotebookExecutionRecord: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var startedAt: String
    var finishedAt: String
    var status: NotebookExecutionStatus
    var target: NotebookExecutionTarget
    var stdout: String
    var stderr: String
    var provenance: NotebookExecutionProvenance

    enum CodingKeys: String, CodingKey {
        case id
        case startedAt = "started_at"
        case finishedAt = "finished_at"
        case status
        case target
        case stdout
        case stderr
        case provenance
    }
}

struct NotebookCell: Codable, Identifiable, Hashable, Sendable {
    var id: String
    var kind: NotebookCellKind
    var source: String
    var target: NotebookExecutionTarget?
    var executions: [NotebookExecutionRecord]

    static func fresh(kind: NotebookCellKind) -> NotebookCell {
        let target: NotebookExecutionTarget?
        switch kind {
        case .markdown: target = nil
        case .code: target = .python
        case .engine: target = .centl
        case .ai: target = .openAI
        }
        return NotebookCell(id: UUID().uuidString, kind: kind, source: "", target: target, executions: [])
    }
}

struct NotebookFile: Codable, Hashable, Sendable {
    var schemaVersion: String
    var id: String
    var title: String
    var metadata: [String: String]
    var cells: [NotebookCell]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case id
        case title
        case metadata
        case cells
    }

    static func fresh(title: String) -> NotebookFile {
        NotebookFile(
            schemaVersion: fcfNotebookSchemaVersion,
            id: UUID().uuidString,
            title: title,
            metadata: [:],
            cells: [
                NotebookCell(
                    id: UUID().uuidString,
                    kind: .markdown,
                    source: "# \(title)\n",
                    target: nil,
                    executions: []
                ),
                NotebookCell.fresh(kind: .code),
            ]
        )
    }
}

@MainActor
final class NotebookDocument: ObservableObject, Identifiable {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    let id = UUID()
    let url: URL

    @Published private(set) var notebook: NotebookFile
    @Published private(set) var state: State = .loading
    @Published private(set) var isDirty = false
    @Published private(set) var runningCellID: String?

    init(url: URL) {
        self.url = url.standardizedFileURL
        self.notebook = .fresh(title: url.deletingPathExtension().lastPathComponent)
    }

    var title: String { notebook.title }

    func load() async {
        state = .loading
        let url = self.url
        let result = await Task.detached(priority: .userInitiated) { () -> Result<NotebookFile, Error> in
            do {
                let data = try Data(contentsOf: url)
                let decoded = try JSONDecoder().decode(NotebookFile.self, from: data)
                guard decoded.schemaVersion == fcfNotebookSchemaVersion else {
                    throw NotebookDocumentError.unsupportedSchema(decoded.schemaVersion)
                }
                return .success(decoded)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let notebook):
            self.notebook = notebook
            isDirty = false
            state = .ready
        case .failure(let error):
            state = .failed(error.localizedDescription)
        }
    }

    func save() async {
        let snapshot = notebook
        let url = self.url
        let result = await Task.detached(priority: .userInitiated) { () -> Result<Void, Error> in
            do {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
                return .success(())
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success:
            isDirty = false
            state = .ready
        case .failure(let error):
            state = .failed(error.localizedDescription)
        }
    }

    func setTitle(_ title: String) {
        guard notebook.title != title else { return }
        notebook.title = title
        isDirty = true
    }

    func updateSource(cellID: String, source: String) {
        guard let index = notebook.cells.firstIndex(where: { $0.id == cellID }),
              notebook.cells[index].source != source else { return }
        notebook.cells[index].source = source
        isDirty = true
    }

    func updateTarget(cellID: String, target: NotebookExecutionTarget) {
        guard let index = notebook.cells.firstIndex(where: { $0.id == cellID }) else { return }
        notebook.cells[index].target = target
        isDirty = true
    }

    func addCell(_ kind: NotebookCellKind, after cellID: String? = nil) {
        let cell = NotebookCell.fresh(kind: kind)
        if let cellID, let index = notebook.cells.firstIndex(where: { $0.id == cellID }) {
            notebook.cells.insert(cell, at: index + 1)
        } else {
            notebook.cells.append(cell)
        }
        isDirty = true
    }

    func removeCell(_ id: String) {
        notebook.cells.removeAll { $0.id == id }
        isDirty = true
    }

    func runCell(_ id: String, projectURL: URL, aiExecutor: (any NotebookAIExecuting)?) {
        guard runningCellID == nil,
              let cell = notebook.cells.first(where: { $0.id == id }),
              cell.kind != .markdown,
              cell.target != nil else { return }
        runningCellID = id

        Task {
            let record = await NotebookExecutionService.execute(
                cell: cell,
                projectURL: projectURL,
                aiExecutor: aiExecutor
            )
            guard let index = notebook.cells.firstIndex(where: { $0.id == id }) else {
                runningCellID = nil
                return
            }
            notebook.cells[index].executions.append(record)
            isDirty = true
            runningCellID = nil
            await save()
        }
    }

    static func create(at url: URL, title: String) async throws {
        let notebook = NotebookFile.fresh(title: title)
        try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(notebook)
            try data.write(to: url, options: .atomic)
        }.value
    }
}

enum NotebookDocumentError: LocalizedError {
    case unsupportedSchema(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let schema):
            return "Unsupported notebook schema: \(schema)"
        }
    }
}
