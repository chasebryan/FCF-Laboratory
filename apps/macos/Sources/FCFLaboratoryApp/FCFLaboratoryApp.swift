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
    enum PendingAction {
        case openProject
        case cloneRepository
        case newWorkspace
    }

    @Published var isCommandPalettePresented = false
    @Published var pendingAction: PendingAction?
    @Published var activeObjectTitle = "FCF Laboratory"
}
