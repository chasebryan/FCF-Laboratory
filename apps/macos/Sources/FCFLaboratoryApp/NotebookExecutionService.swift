import CryptoKit
import Foundation

struct NotebookAIResult: Sendable {
    let text: String
    let provider: String
    let requestID: String?
}

enum NotebookAIExecutionError: Error, Sendable {
    case unavailable(String)
    case failed(String)
}

protocol NotebookAIExecuting: Sendable {
    func executeNotebookPrompt(_ prompt: String, projectURL: URL) async -> Result<NotebookAIResult, NotebookAIExecutionError>
}

enum NotebookExecutionService {
    private static let maxCapturedOutputBytes = 2 * 1_024 * 1_024

    static func execute(
        cell: NotebookCell,
        projectURL: URL,
        aiExecutor: (any NotebookAIExecuting)?
    ) async -> NotebookExecutionRecord {
        let target = cell.target ?? .python
        let startedAt = timestamp()
        let digest = sourceDigest(cell.source)

        if target.kind == .ai {
            guard let aiExecutor else {
                return record(
                    cell: cell,
                    target: target,
                    startedAt: startedAt,
                    status: .failed,
                    stdout: "",
                    stderr: "AI provider is not configured.",
                    provider: target.identifier ?? "ai",
                    command: [],
                    projectURL: projectURL,
                    digest: digest
                )
            }

            let result = await aiExecutor.executeNotebookPrompt(cell.source, projectURL: projectURL)
            switch result {
            case .success(let response):
                var command = ["ai", response.provider]
                if let requestID = response.requestID { command.append(requestID) }
                return record(
                    cell: cell,
                    target: target,
                    startedAt: startedAt,
                    status: .succeeded,
                    stdout: response.text,
                    stderr: "",
                    provider: response.provider,
                    command: command,
                    projectURL: projectURL,
                    digest: digest
                )
            case .failure(let error):
                let message: String
                switch error {
                case .unavailable(let value), .failed(let value): message = value
                }
                return record(
                    cell: cell,
                    target: target,
                    startedAt: startedAt,
                    status: .failed,
                    stdout: "",
                    stderr: message,
                    provider: target.identifier ?? "ai",
                    command: [],
                    projectURL: projectURL,
                    digest: digest
                )
            }
        }

        return await Task.detached(priority: .userInitiated) {
            executeProcess(cell: cell, target: target, projectURL: projectURL, startedAt: startedAt, digest: digest)
        }.value
    }

    private static func executeProcess(
        cell: NotebookCell,
        target: NotebookExecutionTarget,
        projectURL: URL,
        startedAt: String,
        digest: String
    ) -> NotebookExecutionRecord {
        let command: [String]
        let input: String?

        switch target.kind {
        case .python:
            command = ["/usr/bin/env", target.identifier ?? "python3", "-c", cell.source]
            input = nil
        case .shell:
            command = ["/bin/zsh", "-lc", cell.source]
            input = nil
        case .engine:
            guard let executable = target.identifier, !executable.isEmpty else {
                return record(
                    cell: cell,
                    target: target,
                    startedAt: startedAt,
                    status: .failed,
                    stdout: "",
                    stderr: "Engine target is missing an executable identifier.",
                    provider: "engine",
                    command: [],
                    projectURL: projectURL,
                    digest: digest
                )
            }
            command = ["/usr/bin/env", executable]
            input = cell.source
        case .ai:
            preconditionFailure("AI execution is handled before process dispatch")
        }

        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("fcf-notebook-\(UUID().uuidString)", isDirectory: true)
        let stdoutURL = temporaryDirectory.appendingPathComponent("stdout")
        let stderrURL = temporaryDirectory.appendingPathComponent("stderr")
        let stdinURL = temporaryDirectory.appendingPathComponent("stdin")

        do {
            try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
            FileManager.default.createFile(atPath: stdoutURL.path, contents: nil)
            FileManager.default.createFile(atPath: stderrURL.path, contents: nil)
            if let input {
                try Data(input.utf8).write(to: stdinURL, options: .atomic)
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: command[0])
            process.arguments = Array(command.dropFirst())
            process.currentDirectoryURL = projectURL

            let stdoutHandle = try FileHandle(forWritingTo: stdoutURL)
            let stderrHandle = try FileHandle(forWritingTo: stderrURL)
            process.standardOutput = stdoutHandle
            process.standardError = stderrHandle

            var stdinHandle: FileHandle?
            if input != nil {
                stdinHandle = try FileHandle(forReadingFrom: stdinURL)
                process.standardInput = stdinHandle
            }

            try process.run()
            process.waitUntilExit()
            try? stdoutHandle.close()
            try? stderrHandle.close()
            try? stdinHandle?.close()

            let stdout = readBounded(stdoutURL)
            let stderr = readBounded(stderrURL)
            try? FileManager.default.removeItem(at: temporaryDirectory)

            return record(
                cell: cell,
                target: target,
                startedAt: startedAt,
                status: process.terminationStatus == 0 ? .succeeded : .failed,
                stdout: stdout,
                stderr: stderr,
                provider: target.identifier ?? target.kind.rawValue,
                command: command,
                projectURL: projectURL,
                digest: digest
            )
        } catch {
            try? FileManager.default.removeItem(at: temporaryDirectory)
            return record(
                cell: cell,
                target: target,
                startedAt: startedAt,
                status: .failed,
                stdout: "",
                stderr: error.localizedDescription,
                provider: target.identifier ?? target.kind.rawValue,
                command: command,
                projectURL: projectURL,
                digest: digest
            )
        }
    }

    private static func record(
        cell: NotebookCell,
        target: NotebookExecutionTarget,
        startedAt: String,
        status: NotebookExecutionStatus,
        stdout: String,
        stderr: String,
        provider: String,
        command: [String],
        projectURL: URL,
        digest: String
    ) -> NotebookExecutionRecord {
        NotebookExecutionRecord(
            id: UUID().uuidString,
            startedAt: startedAt,
            finishedAt: timestamp(),
            status: status,
            target: target,
            stdout: stdout,
            stderr: stderr,
            provenance: NotebookExecutionProvenance(
                sourceDigest: digest,
                workingDirectory: projectURL.standardizedFileURL.path,
                provider: provider,
                command: command,
                hostOS: hostOS,
                hostArch: hostArch
            )
        )
    }

    private static func sourceDigest(_ source: String) -> String {
        let digest = SHA256.hash(data: Data(source.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func readBounded(_ url: URL) -> String {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return "" }
        defer { try? handle.close() }
        let data = (try? handle.read(upToCount: maxCapturedOutputBytes)) ?? Data()
        var value = String(data: data, encoding: .utf8) ?? ""
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size > maxCapturedOutputBytes {
            value += "\n[output truncated by FCF-Laboratory]"
        }
        return value
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }

    private static var hostOS: String {
        #if os(macOS)
        "macos"
        #elseif os(Linux)
        "linux"
        #elseif os(Windows)
        "windows"
        #else
        "unknown"
        #endif
    }

    private static var hostArch: String {
        #if arch(arm64)
        "arm64"
        #elseif arch(x86_64)
        "x86_64"
        #else
        "unknown"
        #endif
    }
}
