import SwiftUI

struct NotebookView: View {
    @ObservedObject var document: NotebookDocument
    let projectURL: URL
    let aiExecutor: (any NotebookAIExecuting)?

    var body: some View {
        Group {
            switch document.state {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: 8) {
                    Text("Unable to open notebook")
                        .font(.system(size: 14, weight: .medium))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                notebookSurface
            }
        }
    }

    private var notebookSurface: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                TextField(
                    "Notebook title",
                    text: Binding(
                        get: { document.notebook.title },
                        set: { document.setTitle($0) }
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 23, weight: .semibold))
                .tracking(-0.45)
                .padding(.bottom, 8)

                ForEach(document.notebook.cells) { cell in
                    NotebookCellView(
                        document: document,
                        cell: cell,
                        projectURL: projectURL,
                        aiExecutor: aiExecutor
                    )
                }

                Menu {
                    Button("Markdown") { document.addCell(.markdown) }
                    Button("Code") { document.addCell(.code) }
                    Button("Engine") { document.addCell(.engine) }
                    Button("AI") { document.addCell(.ai) }
                } label: {
                    Label("Add Cell", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                }
                .menuStyle(.borderlessButton)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 30)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

private struct NotebookCellView: View {
    @ObservedObject var document: NotebookDocument
    let cell: NotebookCell
    let projectURL: URL
    let aiExecutor: (any NotebookAIExecuting)?

    private var isRunning: Bool { document.runningCellID == cell.id }
    private var latestExecution: NotebookExecutionRecord? { cell.executions.last }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(cell.kind.rawValue.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.7)
                    .foregroundStyle(.tertiary)

                if cell.kind != .markdown {
                    targetMenu
                }

                Spacer()

                if !cell.executions.isEmpty {
                    Text("\(cell.executions.count) run\(cell.executions.count == 1 ? "" : "s")")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                if cell.kind != .markdown {
                    Button {
                        document.runCell(cell.id, projectURL: projectURL, aiExecutor: aiExecutor)
                    } label: {
                        if isRunning {
                            ProgressView()
                                .controlSize(.mini)
                                .frame(width: 18, height: 18)
                        } else {
                            Image(systemName: "play.fill")
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 18, height: 18)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(document.runningCellID != nil || cell.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Run cell")
                }

                Menu {
                    Button("Add Markdown Below") { document.addCell(.markdown, after: cell.id) }
                    Button("Add Code Below") { document.addCell(.code, after: cell.id) }
                    Button("Add Engine Below") { document.addCell(.engine, after: cell.id) }
                    Button("Add AI Below") { document.addCell(.ai, after: cell.id) }
                    Divider()
                    Button("Delete Cell", role: .destructive) { document.removeCell(cell.id) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 10))
                        .frame(width: 18, height: 18)
                }
                .menuStyle(.borderlessButton)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 34)

            Rectangle()
                .fill(Color.primary.opacity(0.055))
                .frame(height: 1)

            TextEditor(text: Binding(
                get: {
                    document.notebook.cells.first(where: { $0.id == cell.id })?.source ?? cell.source
                },
                set: { document.updateSource(cellID: cell.id, source: $0) }
            ))
            .font(cell.kind == .markdown ? .system(size: 13) : .system(size: 12, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: cell.kind == .markdown ? 82 : 112)

            if let execution = latestExecution {
                executionView(execution)
            }
        }
        .background(Color.primary.opacity(0.025))
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(Color.primary.opacity(0.065), lineWidth: 1)
        }
    }

    private var targetMenu: some View {
        Menu {
            Button("Python") { document.updateTarget(cellID: cell.id, target: .python) }
            Button("Shell") { document.updateTarget(cellID: cell.id, target: .shell) }
            Divider()
            Button("CENTL") { document.updateTarget(cellID: cell.id, target: .centl) }
            Button("CBX") { document.updateTarget(cellID: cell.id, target: .cbx) }
            Divider()
            Button("OpenAI") { document.updateTarget(cellID: cell.id, target: .openAI) }
        } label: {
            HStack(spacing: 4) {
                Text(cell.target?.displayName ?? "Target")
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .semibold))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private func executionView(_ execution: NotebookExecutionRecord) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 7) {
                Circle()
                    .fill(execution.status == .succeeded ? Color.secondary : Color.primary.opacity(0.28))
                    .frame(width: 5, height: 5)
                Text(execution.status.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(execution.provenance.sourceDigest.prefix(20)) + "…")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .help(execution.provenance.sourceDigest)
            }

            if !execution.stdout.isEmpty {
                Text(execution.stdout)
                    .font(.system(size: 11, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !execution.stderr.isEmpty {
                Text(execution.stderr)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text("\(execution.provenance.provider) · \(execution.finishedAt)")
                .font(.system(size: 8))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.primary.opacity(0.018))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)
        }
    }
}
