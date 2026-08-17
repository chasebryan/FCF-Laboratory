import AppKit
import SwiftUI

struct WorkspaceView: View {
    @EnvironmentObject private var model: LaboratoryModel

    var body: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Rectangle()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 1)

                workspaceSurface
            }

            if model.isCommandPalettePresented {
                CommandPaletteView(openProject: openProject)
                    .environmentObject(model)
                    .padding(.top, 72)
                    .transition(.opacity.combined(with: .scale(scale: 0.985, anchor: .top)))
                    .zIndex(10)
            }
        }
        .animation(.easeOut(duration: 0.12), value: model.isCommandPalettePresented)
        .onChange(of: model.pendingAction) { _, action in
            guard let action else { return }
            defer { model.pendingAction = nil }

            switch action {
            case .openProject:
                openProject()
            case .cloneRepository, .newWorkspace:
                break
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Text(model.activeObjectTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary.opacity(0.82))
                .lineLimit(1)

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

    private var workspaceSurface: some View {
        VStack(spacing: 18) {
            Spacer()

            VStack(spacing: 9) {
                Text("FCF Laboratory")
                    .font(.system(size: 28, weight: .semibold, design: .default))
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

                Text("⌘K for commands")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }

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
        model.activeObjectTitle = url.lastPathComponent
    }
}

private struct CommandPaletteView: View {
    @EnvironmentObject private var model: LaboratoryModel
    @FocusState private var searchFocused: Bool
    @State private var query = ""

    let openProject: () -> Void

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

            VStack(spacing: 4) {
                commandRow("Open Project", shortcut: "⌘O") {
                    model.isCommandPalettePresented = false
                    openProject()
                }

                commandRow("Dismiss", shortcut: "esc") {
                    model.isCommandPalettePresented = false
                }
            }
            .padding(8)
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

    private func commandRow(_ title: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Text(shortcut)
                    .foregroundStyle(.tertiary)
            }
            .font(.system(size: 13))
            .padding(.horizontal, 10)
            .frame(height: 34)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
