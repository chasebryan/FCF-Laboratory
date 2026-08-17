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
            }
        }
    }
}

@MainActor
final class LaboratoryModel: ObservableObject {
    enum PendingAction: Equatable {
        case openProject
        case showGitStatus
    }

    @Published var isCommandPalettePresented = false
    @Published var isNavigatorPresented = false
    @Published var pendingAction: PendingAction?
    @Published var gitSnapshot: GitSnapshot?
    @Published var session = WorkspaceSession()

    let commands = CommandRegistry.foundation

    var activeObjectTitle: String {
        session.activeObject?.title ?? "FCF Laboratory"
    }

    func openProject(_ url: URL) {
        session.openProject(url)
        isNavigatorPresented = true
        gitSnapshot = nil

        Task {
            gitSnapshot = await GitRepository.snapshot(at: url)
        }
    }
}
