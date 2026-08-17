import Foundation

struct GitChange: Identifiable, Hashable, Sendable {
    enum State: String, Sendable {
        case added
        case modified
        case deleted
        case renamed
        case untracked
        case conflicted
        case other
    }

    let id: String
    let path: String
    let state: State
    let staged: Bool
}

struct GitWorkspaceState: Hashable, Sendable {
    let branch: String
    let changes: [GitChange]

    var isDirty: Bool { !changes.isEmpty }
}

enum GitWorkspaceService {
    static func state(at projectURL: URL) async -> GitWorkspaceState? {
        await Task.detached(priority: .utility) {
            guard FileManager.default.fileExists(atPath: projectURL.appendingPathComponent(".git").path) else { return nil }
            let branch = runGit(["rev-parse", "--abbrev-ref", "HEAD"], at: projectURL).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !branch.isEmpty else { return nil }
            let porcelain = runGit(["status", "--porcelain=v1", "-z"], at: projectURL)
            return GitWorkspaceState(branch: branch, changes: parsePorcelain(porcelain))
        }.value
    }

    static func diff(path: String?, staged: Bool, at projectURL: URL) async -> String {
        await Task.detached(priority: .utility) {
            var arguments = ["diff"]
            if staged { arguments.append("--cached") }
            if let path { arguments += ["--", path] }
            return runGit(arguments, at: projectURL)
        }.value
    }

    private static func parsePorcelain(_ output: String) -> [GitChange] {
        let records = output.split(separator: "\0", omittingEmptySubsequences: true)
        var changes: [GitChange] = []
        var index = 0

        while index < records.count {
            let record = String(records[index])
            guard record.count >= 4 else { index += 1; continue }
            let chars = Array(record)
            let x = chars[0]
            let y = chars[1]
            let path = String(record.dropFirst(3))
            let status = state(x: x, y: y)
            let staged = x != " " && x != "?"
            changes.append(.init(id: "\(index):\(path)", path: path, state: status, staged: staged))

            if x == "R" || x == "C" { index += 2 } else { index += 1 }
        }
        return changes
    }

    private static func state(x: Character, y: Character) -> GitChange.State {
        if x == "?" && y == "?" { return .untracked }
        if x == "U" || y == "U" || (x == "A" && y == "A") || (x == "D" && y == "D") { return .conflicted }
        if x == "R" || y == "R" { return .renamed }
        if x == "A" || y == "A" { return .added }
        if x == "D" || y == "D" { return .deleted }
        if x == "M" || y == "M" { return .modified }
        return .other
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
