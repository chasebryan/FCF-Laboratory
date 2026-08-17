import XCTest
@testable import FCFLaboratoryApp

@MainActor
final class TerminalServicesTests: XCTestCase {
    func testPTYStartsInProjectDirectoryAndCarriesInteractiveInput() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("fcf-terminal-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }

        let terminal = TerminalSession(workingDirectory: project)
        terminal.start(columns: 80, rows: 24)
        XCTAssertTrue(terminal.isRunning, terminal.failureMessage ?? "PTY failed to start")

        terminal.send("printf 'FCF_PTY_OK\\n'\n")

        for _ in 0..<60 {
            if terminal.output.contains("FCF_PTY_OK") { break }
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertTrue(terminal.output.contains("FCF_PTY_OK"))
        terminal.stop()
        XCTAssertFalse(terminal.isRunning)
    }
}
