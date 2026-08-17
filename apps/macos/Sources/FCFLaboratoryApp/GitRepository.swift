import Foundation

struct GitSnapshot: Equatable {
    let branch: String
    let isDirty: Bool
}

enum GitRepository {
    static func snapshot(at projectURL: URL) async -> GitSnapshot? {
        await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(".git").path) else {
                return nil
            }

            let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: projectURL)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !branch.isEmpty else { return nil }

            let status = runGit(["status", "--porcelain"], at: projectURL)
            return GitSnapshot(branch: branch, isDirty: !status.isEmpty)
        }.value
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
        let data = output.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
