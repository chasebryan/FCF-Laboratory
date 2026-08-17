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
        }
        .animation(.easeOut(duration: 0.12), value: model.isCommandPalettePresented)
        .animation(.easeOut(duration: 0.14), value: model.isNavigatorPresented)
        .onChange(of: model.pendingAction) { _, action in
            guard let action else { return }
            defer { model.pendingAction = nil }

            switch action {
            case .openProject:
                openProject()
            case .showGitStatus:
                model.isNavigatorPresented = true
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
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

            if let git = model.gitSnapshot {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(git.branch)
                    if git.isDirty {
                        Circle()
                            .frame(width: 5, height: 5)
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 24)

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
                    Button {
                        model.session.activeObjectID = object.id
                    } label: {
                        HStack(spacing: 7) {
                            Text(object.title)
                                .lineLimit(1)

                            if object.id == model.session.activeObjectID {
                                Button {
                                    model.session.closeObject(object.id)
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 8, weight: .semibold))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .font(.system(size: 11, weight: object.id == model.session.activeObjectID ? .medium : .regular))
                        .foregroundStyle(object.id == model.session.activeObjectID ? .primary : .secondary)
                        .padding(.horizontal, 10)
                        .frame(height: 30)
                        .background {
                            if object.id == model.session.activeObjectID {
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(Color.primary.opacity(0.055))
                            }
                        }
                    }
                    .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 10) {
                    Label(project.lastPathComponent, systemImage: "folder")
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)

                    if let git = model.gitSnapshot {
                        Label(git.branch, systemImage: "arrow.triangle.branch")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
            } else {
                Text("No project open")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(14)
            }

            Spacer()
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private var workspaceSurface: some View {
        if model.session.projectURL == nil {
            welcomeSurface
        } else {
            activeObjectSurface
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

    private var activeObjectSurface: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "square.grid.2x2")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)

            Text(model.session.activeObject?.title ?? "Workspace")
                .font(.system(size: 16, weight: .medium))

            Text("Object rendering arrives here. The shell is already workspace-aware.")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        case "navigator.toggle":
            model.isNavigatorPresented.toggle()
        case "git.status":
            model.pendingAction = .showGitStatus
        default:
            break
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
            .frame(maxHeight: 260)
        }
        .frame(width: 520)
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
