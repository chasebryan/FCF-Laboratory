import AppKit
import SwiftUI

struct WorkspaceUtilityPanel: View {
    @EnvironmentObject private var model: LaboratoryModel
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    private var panel: LaboratoryModel.UtilityPanel? { model.utilityPanel }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.4)
                Spacer()
                Button { model.utilityPanel = nil } label: {
                    Image(systemName: "xmark").font(.system(size: 9, weight: .semibold)).frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 38)

            if needsSearchField {
                Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.tertiary)
                    TextField(searchPlaceholder, text: $query)
                        .textFieldStyle(.plain)
                        .focused($searchFocused)
                        .font(.system(size: 12))
                        .onSubmit { submitFirstMatch() }
                }
                .padding(.horizontal, 14)
                .frame(height: 38)
            }

            Rectangle().fill(Color.primary.opacity(0.06)).frame(height: 1)
            content
        }
        .frame(width: 760)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.primary.opacity(0.08), lineWidth: 1) }
        .shadow(color: .black.opacity(0.14), radius: 26, y: 12)
        .onAppear {
            searchFocused = needsSearchField
            if panel == .search { model.searchProject(query) }
            if panel == .git { model.refreshGitWorkspace() }
            if panel == .github { model.githubWorkspace.refresh(remote: model.githubRemote) }
        }
        .onChange(of: query) { _, value in if panel == .search { model.searchProject(value) } }
        .onExitCommand { model.utilityPanel = nil }
    }

    private var needsSearchField: Bool { panel == .quickOpen || panel == .search || panel == .symbols }

    private var title: String {
        switch panel {
        case .quickOpen: return "QUICK OPEN"
        case .search: return "PROJECT SEARCH"
        case .symbols: return "DOCUMENT SYMBOLS"
        case .tasks: return "TASKS"
        case .git: return "GIT"
        case .github: return "GITHUB"
        case .ai: return "AI"
        case .none: return ""
        }
    }

    private var searchPlaceholder: String {
        switch panel {
        case .quickOpen: return "File name or path"
        case .search: return "Search project text"
        case .symbols: return "Filter symbols"
        default: return "Filter"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch panel {
        case .quickOpen: quickOpenContent
        case .search: searchContent
        case .symbols: symbolsContent
        case .tasks: tasksContent
        case .git: gitContent
        case .github:
            GitHubWorkspacePanel(controller: model.githubWorkspace, remote: model.githubRemote)
                .frame(maxHeight: 490)
        case .ai:
            AIWorkspacePanel(
                controller: model.aiWorkspace,
                contextProvider: { model.aiContextSnapshot }
            )
            .frame(maxHeight: 530)
        case .none: EmptyView()
        }
    }

    private var quickOpenMatches: [ProjectEntry] {
        let files = model.projectEntries.filter { $0.kind == .file }
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return Array(files.prefix(80)) }
        return Array(files.filter { entry in
            entry.name.lowercased().contains(normalized) || relativePath(entry.url).lowercased().contains(normalized)
        }.prefix(80))
    }

    private var quickOpenContent: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(quickOpenMatches) { entry in
                    Button { model.openFile(entry.url); model.utilityPanel = nil } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "doc").font(.system(size: 10)).foregroundStyle(.tertiary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(entry.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                Text(relativePath(entry.url)).font(.system(size: 9.5)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 12).frame(height: 34).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
            }.padding(.vertical, 6)
        }.frame(maxHeight: 330)
    }

    private var searchContent: some View {
        Group {
            if model.isSearchingProject {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 170)
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type to search indexed project files.").font(.system(size: 10.5)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 170)
            } else if model.projectSearchResults.isEmpty {
                Text("No matches").font(.system(size: 10.5)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 170)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(model.projectSearchResults) { result in
                            Button { model.openFile(result.url, line: result.line); model.utilityPanel = nil } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Text("\(result.line)").font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 35, alignment: .trailing)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(relativePath(result.url)).font(.system(size: 10, weight: .medium)).lineLimit(1)
                                        Text(result.preview).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).lineLimit(2)
                                    }
                                    Spacer()
                                }.padding(.horizontal, 12).padding(.vertical, 6).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 4)
                }.frame(maxHeight: 330)
            }
        }
    }

    private var symbolsContent: some View {
        let symbols = filteredSymbols
        return Group {
            if symbols.isEmpty {
                Text(model.activeEditorDocument == nil ? "Open a source file first." : "No local symbols detected.")
                    .font(.system(size: 10.5)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 170)
            } else {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        ForEach(symbols) { symbol in
                            Button { model.showSymbol(symbol) } label: {
                                HStack(spacing: 9) {
                                    Image(systemName: symbolIcon(symbol.kind)).font(.system(size: 9)).foregroundStyle(.tertiary).frame(width: 14)
                                    Text(symbol.name).font(.system(size: 11, weight: .medium)).lineLimit(1)
                                    Spacer()
                                    Text("\(symbol.line)").font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary)
                                }.padding(.horizontal, 12).frame(height: 30).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(.vertical, 5)
                }.frame(maxHeight: 330)
            }
        }
    }

    private var filteredSymbols: [DocumentSymbol] {
        guard let document = model.activeEditorDocument else { return [] }
        let symbols = document.symbols
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty ? symbols : symbols.filter { $0.name.lowercased().contains(normalized) }
    }

    private var tasksContent: some View {
        VStack(spacing: 0) {
            if model.availableTasks.isEmpty {
                Text("No foundation tasks detected for this project.").font(.system(size: 10.5)).foregroundStyle(.tertiary).frame(maxWidth: .infinity, minHeight: 130)
            } else {
                ForEach(model.availableTasks) { task in
                    Button { model.runTask(task) } label: {
                        HStack(spacing: 9) {
                            Image(systemName: model.runningTaskID == task.id ? "hourglass" : "play.fill").font(.system(size: 9)).foregroundStyle(.tertiary).frame(width: 14)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(task.title).font(.system(size: 11, weight: .medium))
                                Text(task.command.joined(separator: " ")).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary).lineLimit(1)
                            }
                            Spacer()
                        }.padding(.horizontal, 12).frame(height: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(model.runningTaskID != nil)
                }
            }
            if let result = model.lastTaskResult {
                Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1)
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text(result.title).font(.system(size: 10, weight: .semibold)); Spacer(); Text("exit \(result.exitCode)").font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary) }
                    if !result.stdout.isEmpty { Text(result.stdout).font(.system(size: 10, design: .monospaced)).textSelection(.enabled) }
                    if !result.stderr.isEmpty { Text(result.stderr).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary).textSelection(.enabled) }
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            }
        }.frame(maxHeight: 350)
    }

    private var gitContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                if let state = model.gitWorkspaceState { Image(systemName: "arrow.triangle.branch"); Text(state.branch).font(.system(size: 11, weight: .semibold)); Text("\(state.changes.count) change\(state.changes.count == 1 ? "" : "s")").font(.system(size: 9.5)).foregroundStyle(.tertiary) }
                else { Text("Not a Git repository").font(.system(size: 10.5)).foregroundStyle(.tertiary) }
                Spacer()
                if let remote = model.githubRemote { Text(remote.slug).font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary) }
                Button { model.refreshGitWorkspace() } label: { Image(systemName: "arrow.clockwise").font(.system(size: 10)) }.buttonStyle(.plain).foregroundStyle(.tertiary)
            }.padding(.horizontal, 12).frame(height: 38)

            Rectangle().fill(Color.primary.opacity(0.05)).frame(height: 1)

            HSplitView {
                ScrollView {
                    LazyVStack(spacing: 1) {
                        if let state = model.gitWorkspaceState {
                            ForEach(state.changes) { change in
                                Button { model.loadGitDiff(change) } label: {
                                    HStack(spacing: 8) {
                                        Text(change.staged ? "S" : "W").font(.system(size: 8.5, weight: .bold, design: .monospaced)).foregroundStyle(.tertiary).frame(width: 12)
                                        Text(gitStateLabel(change.state)).font(.system(size: 8.5, design: .monospaced)).foregroundStyle(.secondary).frame(width: 14)
                                        Text(change.path).font(.system(size: 10.5, design: .monospaced)).lineLimit(1)
                                        Spacer()
                                    }.padding(.horizontal, 9).frame(height: 27).contentShape(Rectangle()).background(model.selectedGitChangeID == change.id ? Color.primary.opacity(0.055) : .clear, in: RoundedRectangle(cornerRadius: 5))
                                }.buttonStyle(.plain)
                            }
                        }
                    }.padding(6)
                }.frame(minWidth: 230, maxWidth: 320, minHeight: 240)

                Group {
                    if model.isLoadingGitDiff { ProgressView().controlSize(.small) }
                    else if model.gitDiffText.isEmpty { Text("Select a change to inspect its diff.").font(.system(size: 10.5)).foregroundStyle(.tertiary) }
                    else { ScrollView([.vertical, .horizontal]) { Text(model.gitDiffText).font(.system(size: 10.5, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .topLeading).padding(10) } }
                }.frame(minWidth: 360, maxWidth: .infinity, minHeight: 240, maxHeight: 330)
            }
        }
    }

    private func relativePath(_ url: URL) -> String {
        guard let root = model.session.projectURL?.standardizedFileURL.path else { return url.lastPathComponent }
        let path = url.standardizedFileURL.path
        let prefix = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(prefix) ? String(path.dropFirst(prefix.count)) : url.lastPathComponent
    }
    private func symbolIcon(_ kind: DocumentSymbol.Kind) -> String {
        switch kind { case .function: return "function"; case .type: return "square.stack.3d.up"; case .property: return "p.square"; case .heading: return "textformat.size" }
    }
    private func gitStateLabel(_ state: GitChange.State) -> String {
        switch state { case .modified: return "M"; case .added: return "A"; case .deleted: return "D"; case .renamed: return "R"; case .copied: return "C"; case .untracked: return "?"; case .unmerged: return "U"; case .unknown: return "·" }
    }
    private func submitFirstMatch() {
        switch panel {
        case .quickOpen: if let entry = quickOpenMatches.first { model.openFile(entry.url); model.utilityPanel = nil }
        case .search: if let result = model.projectSearchResults.first { model.openFile(result.url, line: result.line); model.utilityPanel = nil }
        case .symbols: if let symbol = filteredSymbols.first { model.showSymbol(symbol) }
        default: break
        }
    }
}
