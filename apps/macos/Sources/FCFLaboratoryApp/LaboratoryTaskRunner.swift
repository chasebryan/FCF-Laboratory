import Foundation

struct LaboratoryTaskDescriptor: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let executable: String
    let arguments: [String]
}

struct LaboratoryTaskResult: Hashable, Sendable {
    let taskID: String
    let exitCode: Int32
    let output: String
    let duration: TimeInterval

    var succeeded: Bool { exitCode == 0 }
}

enum LaboratoryTaskRunner {
    static func run(_ descriptor: LaboratoryTaskDescriptor, in directory: URL) async -> LaboratoryTaskResult {
        await Task.detached(priority: .userInitiated) {
            let start = Date()
            let process = Process()
            let output = Pipe()
            let error = Pipe()

            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [descriptor.executable] + descriptor.arguments
            process.currentDirectoryURL = directory
            process.standardOutput = output
            process.standardError = error

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                return LaboratoryTaskResult(
                    taskID: descriptor.id,
                    exitCode: -1,
                    output: error.localizedDescription,
                    duration: Date().timeIntervalSince(start)
                )
            }

            let stdout = output.fileHandleForReading.readDataToEndOfFile()
            let stderr = error.fileHandleForReading.readDataToEndOfFile()
            var combined = String(data: stdout, encoding: .utf8) ?? ""
            let errorText = String(data: stderr, encoding: .utf8) ?? ""
            if !errorText.isEmpty {
                if !combined.isEmpty && !combined.hasSuffix("\n") { combined += "\n" }
                combined += errorText
            }

            return LaboratoryTaskResult(
                taskID: descriptor.id,
                exitCode: process.terminationStatus,
                output: combined,
                duration: Date().timeIntervalSince(start)
            )
        }.value
    }
}

enum FoundationTaskDiscovery {
    static func tasks(for projectURL: URL) -> [LaboratoryTaskDescriptor] {
        var tasks: [LaboratoryTaskDescriptor] = []
        let manager = FileManager.default

        if manager.fileExists(atPath: projectURL.appendingPathComponent("Cargo.toml").path) {
            tasks.append(.init(id: "cargo.check", name: "Cargo Check", executable: "cargo", arguments: ["check"]))
            tasks.append(.init(id: "cargo.test", name: "Cargo Test", executable: "cargo", arguments: ["test"]))
        }
        if manager.fileExists(atPath: projectURL.appendingPathComponent("Package.swift").path) {
            tasks.append(.init(id: "swift.build", name: "Swift Build", executable: "swift", arguments: ["build"]))
            tasks.append(.init(id: "swift.test", name: "Swift Test", executable: "swift", arguments: ["test"]))
        }
        if manager.fileExists(atPath: projectURL.appendingPathComponent("pyproject.toml").path) ||
            manager.fileExists(atPath: projectURL.appendingPathComponent("pytest.ini").path) {
            tasks.append(.init(id: "python.pytest", name: "Pytest", executable: "python3", arguments: ["-m", "pytest"]))
        }

        return tasks
    }
}
