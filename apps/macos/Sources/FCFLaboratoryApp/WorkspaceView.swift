import AppKit
import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var model: LaboratoryModel

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            HStack(spacing: 0) {
                if model.isNavigatorPresented {
                    navigator
                        .transition(.move(edge: .leading).combined(with: .opacity))

                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(width: 1)
                }

                VStack(spacing: 0) {
                    topBar

                    Rectangle()
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 1)

                    if model.session.objects.count > 1 {
                        tabStrip
                    }

                    workspaceSurface
                }
            }

            if model.isCommandPalettePresented {
                CommandPaletteView(execute: executeCommand)
                    .environmentObject(model)
                    .padding(.top, 72)
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                    .zIndex(10)
            }

            if model.utilityPanel != nil {
                WorkspaceUtilityPanel()
                    .environmentObject(model)
                    .padding(.top, 72)
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                    .zIndex(11)
            }
        }
        .animation(.easeOut(duration: 0.12), value: model.isCommandPalettePresented)
        .animation(.easeOut(duration: 0.12), value: model.utilityPanel)
        .animation(.easeOut(duration: 0.14), value: model.isNavigatorPresented)
        .onChange(of: model.pendingAction) { _, action in
            guard let action else { return }
            defer { model.pendingAction = nil }

            switch action {
            case .openProject:
                openProject()
            case .showGitStatus:
                model.utilityPanel = .git
            case .saveActiveDocument:
                model.saveActiveDocument()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            if !model.isNavigatorPresented {
                Button {
                    model.isNavigatorPresented = true
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 12, weight: .medium))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Show Navigator (⌘B)")
            }

            Text(model.activeObjectTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(1)

            if let document = model.activeEditorDocument {
                Text(document.language.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)

                if document.isDirty {
                    Circle()
                        .fill(Color.primary.opacity(0.52))
                        .frame(width: 5, height: 5)
                        .help("Unsaved changes")
                }
            }

            if let git = model.gitSnapshot {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(git.branch)
                    if git.isDirty {
                        Circle()
                            .frame(width: 5, height: 5)
                    }
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

            if let server = model.resolvedLanguageServer {
                Image(systemName: "bolt.horizontal.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .help("Language server available: \(server.descriptor.displayName)")
            }

            Button {
                model.isCommandPalettePresented.toggle()
            } label: {
                Image(systemName: "command")
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Command Palette (⌘K)")
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(model.session.objects) { object in
                    HStack(spacing: 3) {
                        Button {
                            model.session.activeObjectID = object.id
                        } label: {
                            HStack(spacing: 7) {
                                Text(object.title)
                                    .lineLimit(1)

                                if let url = object.url,
                                   model.editorDocuments[url.standardizedFileURL]?.isDirty == true {
                                    Circle()
                                        .frame(width: 4, height: 4)
                                }
                            }
                            .font(.system(size: 11, weight: object.id == model.session.activeObjectID ? .medium : .regular))
                            .foregroundStyle(object.id == model.session.activeObjectID ? .primary : .secondary)
                            .padding(.leading, 10)
                            .padding(.trailing, object.id == model.session.activeObjectID ? 4 : 10)
                            .frame(height: 30)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if object.id == model.session.activeObjectID {
                            Button {
                                model.requestCloseObject(object.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .semibold))
                                    .frame(width: 20, height: 28)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.tertiary)
                        }
                    }
                    .background {
                        if object.id == model.session.activeObjectID {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Color.primary.opacity(0.055))
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.primary.opacity(0.05))
                .frame(height: 1)
        }
    }

    private var navigator: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PROJECT")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(.tertiary)

                Spacer()

                if model.isIndexingProject {
                    ProgressView()
                        .controlSize(.mini)
                }

                Button {
                    model.isNavigatorPresented = false
                } label: {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(height: 44)

            if let project = model.session.projectURL {
                HStack(spacing: 7) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(project.lastPathComponent)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .frame(height: 30)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(model.visibleProjectEntries) { entry in
                            projectEntryRow(entry)
                        }
                    }
                    .padding(.vertical, 4)
                }

                navigatorFooter
            } else {
                Text("No project open")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(14)
                Spacer()
            }
        }
        .frame(width: 240)
        .background(.ultraThinMaterial)
    }

    private var navigatorFooter: some View {
        HStack(spacing: 12) {
            if let git = model.gitSnapshot {
                Button {
                    model.utilityPanel = .git
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.triangle.branch")
                        Text(git.branch)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if !model.availableTasks.isEmpty {
                Button {
                    model.utilityPanel = .tasks
                } label: {
                    Image(systemName: "play")
                }
                .buttonStyle(.plain)
                .help("Tasks")
            }
        }
        .font(.system(size: 10))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .frame(height: 32)
    }

    private func projectEntryRow(_ entry: ProjectEntry) -> some View {
        let isDirectory = entry.kind == .directory
        let expanded = model.expandedDirectoryPaths.contains(entry.url.standardizedFileURL.path)

        return Button {
            if isDirectory {
                model.toggleDirectory(entry.url)
            } else {
                model.openFile(entry.url)
            }
        } label: {
            HStack(spacing: 5) {
                Group {
                    if isDirectory {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 7, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    } else {
                        Color.clear
                    }
                }
                .frame(width: 8, height: 12)

                Image(systemName: isDirectory ? "folder" : "doc")
                    .font(.system(size: 10))
                    .foregroundStyle(isDirectory ? .secondary : .tertiary)
                    .frame(width: 14)

                Text(entry.name)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .font(.system(size: 11, weight: isDirectory ? .medium : .regular))
            .foregroundStyle(Color.primary.opacity(isDirectory ? 0.62 : 0.82))
            .padding(.leading, CGFloat(entry.depth) * 12 + 8)
            .padding(.trailing, 10)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var workspaceSurface: some View {
        if model.session.projectURL == nil {
            welcomeSurface
        } else if let object = model.session.activeObject {
            activeObjectSurface(object)
        } else {
            projectSurface
        }
    }

    private var welcomeSurface: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 9) {
                Text("FCF Laboratory")
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.7)

                Text("Open a project. The machinery stays out of the way until you need it.")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button("Open Project") {
                    openProject()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 8)

                if !model.session.recentProjects.isEmpty {
                    VStack(spacing: 5) {
                        ForEach(model.session.recentProjects.prefix(4), id: \.path) { url in
                            Button(url.lastPathComponent) {
                                model.openProject(url)
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }

                Text("⌘K for commands")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var projectSurface: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(model.session.projectURL?.lastPathComponent ?? "Project")
                .font(.system(size: 17, weight: .medium))
            Text("Choose a file from the navigator or press ⌘P.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func activeObjectSurface(_ object: LaboratoryObject) -> some View {
        if object.kind == .paper, let url = object.url {
            PDFDocumentView(url: url)
        } else if let document = model.activeEditorDocument {
            EditorSurface(document: document)
        } else {
            VStack(spacing: 10) {
                Spacer()
                Image(systemName: iconName(for: object.kind))
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
                Text(object.title)
                    .font(.system(size: 16, weight: .medium))
                Text("This object type will receive a native renderer.")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func iconName(for kind: LaboratoryObject.Kind) -> String {
        switch kind {
        case .paper: return "doc.richtext"
        case .dataset: return "tablecells"
        case .notebook: return "rectangle.and.pencil.and.ellipsis"
        default: return "doc"
        }
    }

    private func openProject() {
        let panel = NSOpenPanel()
        panel.title = "Open Project"
        panel.prompt = "Open"
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.resolvesAliases = true

        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.openProject(url)
    }

    private func executeCommand(_ command: LaboratoryCommand) {
        model.isCommandPalettePresented = false

        switch command.id {
        case "project.open":
            openProject()
        case "project.quickOpen":
            model.utilityPanel = .quickOpen
        case "project.search":
            model.utilityPanel = .search
        case "document.symbols":
            model.utilityPanel = .symbols
        case "document.save":
            model.saveActiveDocument()
        case "navigator.toggle":
            model.isNavigatorPresented.toggle()
        case "tasks.show":
            model.utilityPanel = .tasks
        case "git.status":
            model.utilityPanel = .git
        default:
            break
        }
    }
}

private struct EditorSurface: View {
    @ObservedObject var document: EditorDocument

    var body: some View {
        Group {
            switch document.state {
            case .loading:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let message):
                VStack(spacing: 8) {
                    Text("Unable to open this file")
                        .font(.system(size: 14, weight: .medium))
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                CodeEditorView(
                    text: Binding(
                        get: { document.text },
                        set: { document.noteEdit($0) }
                    ),
                    language: document.language,
                    requestedLine: document.requestedLine,
                    onJumpHandled: document.clearRequestedJump,
                    onEdit: document.noteEdit
                )
            }
        }
    }
}

private struct CommandPaletteView: View {
    @EnvironmentObject private var model: LaboratoryModel
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    let execute: (LaboratoryCommand) -> Void

    private var matches: [LaboratoryCommand] {
        model.commands.matches(query)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Type a command", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 16)
            .frame(height: 48)

            Rectangle()
                .fill(Color.primary.opacity(0.07))
                .frame(height: 1)

            ScrollView {
                VStack(spacing: 3) {
                    ForEach(matches) { command in
                        Button {
                            execute(command)
                        } label: {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(command.title)
                                        .foregroundStyle(.primary)
                                    if let subtitle = command.subtitle {
                                        Text(subtitle)
                                            .font(.system(size: 10))
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                if let shortcut = command.shortcut {
                                    Text(shortcut)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .font(.system(size: 13))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 38)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 300)
        }
        .frame(width: 540)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 30, y: 14)
        .onAppear {
            searchFocused = true
        }
        .onExitCommand {
            model.isCommandPalettePresented = false
        }
    }
}
