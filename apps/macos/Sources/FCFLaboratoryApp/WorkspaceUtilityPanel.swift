import Foundation
import SwiftUI

struct WorkspaceUtilityPanel: View {
    @EnvironmentObject private var model: LaboratoryModel
    @FocusState private var fieldFocused: Bool
    @State private var query = ""

    var body: some View {
        VStack(spacing: 0) {
            header

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            content
        }
        .frame(width: 620)
        .frame(maxHeight: 440)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 32, y: 16)
        .onAppear {
            if model.utilityPanel == .search { fieldFocused = true }
        }
        .onExitCommand {
            model.utilityPanel = nil
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Button {
                model.utilityPanel = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    @ViewBuilder
    private var content: some View {
        switch model.utilityPanel {
        case .search:
            searchContent
        case .symbols:
            symbolsContent
        case .tasks:
            tasksContent
        case .git:
            gitContent
        case nil:
            EmptyView()
        }
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search project", text: $query)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onChange(of: query) { _, value in
                        model.searchProject(value)
                    }
                if model.isSearchingProject {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(model.projectSearchResults) { result in
                        Button {
                            model.openFile(result.url, line: result.line)
                            model.utilityPanel = nil
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 10) {
                                Text(result.url.lastPathComponent)
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(width: 130, alignment: .leading)
                                    .lineLimit(1)
                                Text("\(result.line)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 42, alignment: .trailing)
                                Text(result.preview)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 220)
        }
    }

    private var symbolsContent: some View {
        Group {
            if let document = model.activeEditorDocument {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(document.symbols) { symbol in
                            Button {
                                model.showSymbol(symbol)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: symbolIcon(symbol.kind))
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 16)
                                    Text(symbol.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    Text("line \(symbol.line)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 30)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 220)
            } else {
                emptyMessage("Open a source document to inspect symbols.")
            }
        }
    }

    private var tasksContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 4) {
                    if model.availableTasks.isEmpty {
                        emptyMessage("No standard build or test tasks were detected for this project.")
                    } else {
                        ForEach(model.availableTasks) { task in
                            Button {
                                model.runTask(task)
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "play")
                                        .font(.system(size: 9, weight: .semibold))
                                    Text(task.name)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    if model.runningTaskID == task.id {
                                        ProgressView()
                                            .controlSize(.mini)
                                    }
                                }
                                .padding(.horizontal, 12)
                                .frame(height: 34)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(model.runningTaskID != nil)
                        }
                    }
                }
                .padding(8)
            }

            if let result = model.lastTaskResult {
                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(result.succeeded ? "Succeeded" : "Exited \(result.exitCode)")
                            .font(.system(size: 10, weight: .semibold))
                        Spacer()
                        Text(String(format: "%.2fs", result.duration))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    ScrollView {
                        Text(result.output.isEmpty ? "No output" : result.output)
                            .font(.system(size: 10.5, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)
                }
                .padding(12)
            }
        }
        .frame(minHeight: 220)
    }

    private var gitContent: some View {
        VStack(spacing: 0) {
            if let state = model.gitWorkspaceState {
                HStack {
                    Image(systemName: "arrow.triangle.branch")
                    Text(state.branch)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(state.changes.count) change\(state.changes.count == 1 ? "" : "s")")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    Button("Refresh") {
                        model.refreshGitWorkspace()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                }
                .padding(.horizontal, 14)
                .frame(height: 40)

                Rectangle()
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 1)

                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(state.changes) { change in
                            HStack(spacing: 10) {
                                Text(change.state.rawValue.prefix(1).uppercased())
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 14)
                                Text(change.path)
                                    .font(.system(size: 11, design: .monospaced))
                                    .lineLimit(1)
                                Spacer()
                                if change.staged {
                                    Text("staged")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 28)
                        }
                    }
                    .padding(8)
                }
                .frame(minHeight: 220)
            } else {
                emptyMessage("This project is not a Git repository.")
            }
        }
    }

    private var title: String {
        switch model.utilityPanel {
        case .search: return "Search Project"
        case .symbols: return "Document Symbols"
        case .tasks: return "Tasks"
        case .git: return "Git"
        case nil: return "Laboratory"
        }
    }

    private func symbolIcon(_ kind: DocumentSymbol.Kind) -> String {
        switch kind {
        case .type: return "square.stack.3d.up"
        case .function, .method: return "function"
        case .property: return "circle.fill"
        case .module: return "shippingbox"
        case .other: return "diamond"
        }
    }

    private func emptyMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, minHeight: 180)
            .padding(20)
    }
}
