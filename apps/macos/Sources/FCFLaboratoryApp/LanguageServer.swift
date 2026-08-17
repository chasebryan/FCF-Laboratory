import Foundation

struct LanguageServerDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let language: LanguageID
    let displayName: String
    let executableCandidates: [String]
    let arguments: [String]
}

struct ResolvedLanguageServer: Hashable, Sendable {
    let descriptor: LanguageServerDescriptor
    let executableURL: URL
}

enum LanguageServerRegistry {
    static let foundation: [LanguageServerDescriptor] = [
        .init(id: "sourcekit-lsp", language: .swift, displayName: "SourceKit-LSP", executableCandidates: ["sourcekit-lsp"], arguments: []),
        .init(id: "rust-analyzer", language: .rust, displayName: "rust-analyzer", executableCandidates: ["rust-analyzer"], arguments: []),
        .init(id: "pyright-langserver", language: .python, displayName: "Pyright", executableCandidates: ["pyright-langserver"], arguments: ["--stdio"]),
        .init(id: "clangd-c", language: .c, displayName: "clangd", executableCandidates: ["clangd"], arguments: []),
        .init(id: "clangd-cpp", language: .cpp, displayName: "clangd", executableCandidates: ["clangd"], arguments: []),
        .init(id: "typescript-language-server", language: .typescript, displayName: "TypeScript Language Server", executableCandidates: ["typescript-language-server"], arguments: ["--stdio"]),
        .init(id: "ocamllsp", language: .ocaml, displayName: "OCaml-LSP", executableCandidates: ["ocamllsp"], arguments: []),
    ]

    static func descriptor(for language: LanguageID) -> LanguageServerDescriptor? {
        foundation.first { $0.language == language }
    }
}

enum LanguageServerDiscovery {
    static func resolve(for language: LanguageID) async -> ResolvedLanguageServer? {
        guard let descriptor = LanguageServerRegistry.descriptor(for: language) else { return nil }
        return await Task.detached(priority: .utility) {
            for candidate in descriptor.executableCandidates {
                if let url = executable(named: candidate) {
                    return ResolvedLanguageServer(descriptor: descriptor, executableURL: url)
                }
            }
            return nil
        }.value
    }

    private static func executable(named name: String) -> URL? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [name]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else { return nil }
            return URL(fileURLWithPath: path)
        } catch {
            return nil
        }
    }
}

/// Protocol seam for a future JSON-RPC Language Server Protocol transport.
/// Discovery and process ownership are separate so unavailable servers never degrade the editor.
protocol LanguageServerTransport: AnyObject {
    func start(server: ResolvedLanguageServer, workspaceURL: URL) async throws
    func stop() async
    func notifyDocumentOpened(url: URL, language: LanguageProfile, text: String) async
    func notifyDocumentChanged(url: URL, version: Int, text: String) async
}
