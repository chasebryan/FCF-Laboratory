import Foundation

struct GitHubRemoteIdentity: Hashable, Sendable {
    let owner: String
    let repository: String
    let remoteURL: String

    var slug: String { "\(owner)/\(repository)" }
}

enum GitHubRemoteService {
    static func detect(at projectURL: URL) async -> GitHubRemoteIdentity? {
        await Task.detached(priority: .utility) {
            let remote = runGit(["remote", "get-url", "origin"], at: projectURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !remote.isEmpty else { return nil }
            return parse(remote)
        }.value
    }

    static func parse(_ remote: String) -> GitHubRemoteIdentity? {
        let cleaned = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        let path: String

        if cleaned.hasPrefix("git@github.com:") {
            path = String(cleaned.dropFirst("git@github.com:".count))
        } else if let url = URL(string: cleaned), url.host?.lowercased() == "github.com" {
            path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        } else {
            return nil
        }

        let withoutGit = path.hasSuffix(".git") ? String(path.dropLast(4)) : path
        let pieces = withoutGit.split(separator: "/", omittingEmptySubsequences: true)
        guard pieces.count == 2 else { return nil }
        return GitHubRemoteIdentity(owner: String(pieces[0]), repository: String(pieces[1]), remoteURL: cleaned)
    }

    private static func runGit(_ arguments: [String], at directory: URL) -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", directory.path] + arguments
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return ""
        }
        guard process.terminationStatus == 0 else { return "" }
        return String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
