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
        .frame(width: 660)
        .frame(maxHeight: 500)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 32, y: 16)
        .onAppear {
            if model.utilityPanel == .quickOpen || model.utilityPanel == .search {
                fieldFocused = true
            }
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
        case .quickOpen:
            quickOpenContent
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

    private var quickOpenMatches: [ProjectEntry] {
        let files = model.projectEntries.filter { $0.kind == .file }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return Array(files.prefix(80)) }
        return Array(files.filter { entry in
            entry.name.lowercased().contains(normalized) || entry.url.path.lowercased().contains(normalized)
        }.prefix(80))
    }

    private var quickOpenContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "doc.text.magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Open file", text: $query)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)

            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(quickOpenMatches) { entry in
                        Button {
                            model.openFile(entry.url)
                            model.utilityPanel = nil
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 14)
                                Text(entry.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                                Spacer()
                                Text(relativePath(entry.url))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 12)
                            .frame(height: 31)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(minHeight: 240)
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
            .frame(minHeight: 240)
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
                .frame(minHeight: 240)
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
                    .frame(maxHeight: 160)
                }
                .padding(12)
            }
        }
        .frame(minHeight: 240)
    }

    private var gitContent: some View {
        VStack(spacing: 0) {
            if let state = model.gitWorkspaceState {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(state.branch)
                        .font(.system(size: 12, weight: .medium))
                    if let github = model.githubRemote {
                        Text(github.slug)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
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

                HSplitView {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(state.changes) { change in
                                Button {
                                    model.loadGitDiff(change)
                                } label: {
                                    HStack(spacing: 9) {
                                        Text(change.state.rawValue.prefix(1).uppercased())
                                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 14)
                                        Text(change.path)
                                            .font(.system(size: 10.5, design: .monospaced))
                                            .lineLimit(1)
                                        Spacer(minLength: 4)
                                        if change.staged {
                                            Text("staged")
                                                .font(.system(size: 8.5))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .padding(.horizontal, 9)
                                    .frame(height: 28)
                                    .contentShape(Rectangle())
                                    .background {
                                        if model.selectedGitChangeID == change.id {
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color.primary.opacity(0.055))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(6)
                    }
                    .frame(minWidth: 210)

                    ZStack {
                        if model.isLoadingGitDiff {
                            ProgressView().controlSize(.small)
                        } else if model.gitDiffText.isEmpty {
                            Text("Select a change to inspect its diff.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.tertiary)
                        } else {
                            ScrollView([.horizontal, .vertical]) {
                                Text(model.gitDiffText)
                                    .font(.system(size: 10.5, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .topLeading)
                                    .padding(10)
                            }
                        }
                    }
                    .frame(minWidth: 320)
                }
                .frame(minHeight: 300)
            } else {
                emptyMessage("This project is not a Git repository.")
            }
        }
    }

    private var title: String {
        switch model.utilityPanel {
        case .quickOpen: return "Quick Open"
        case .search: return "Search Project"
        case .symbols: return "Document Symbols"
        case .tasks: return "Tasks"
        case .git: return "Git"
        case nil: return "Laboratory"
        }
    }

    private func relativePath(_ url: URL) -> String {
        guard let root = model.session.projectURL else { return url.path }
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return path }
        return String(path.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
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
            .frame(maxWidth: .infinity, minHeight: 190)
            .padding(20)
    }
}
