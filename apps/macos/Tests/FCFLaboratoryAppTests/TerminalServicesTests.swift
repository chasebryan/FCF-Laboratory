import XCTest
@testable import FCFLaboratoryApp

@MainActor
final class TerminalServicesTests: XCTestCase {
    func testTerminalSessionStartsStoppedAndKeepsProjectDirectory() throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("fcf-terminal-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }

        let terminal = TerminalSession(workingDirectory: project)
        XCTAssertFalse(terminal.isRunning)
        XCTAssertEqual(terminal.workingDirectory, project.standardizedFileURL)
        XCTAssertNil(terminal.failureMessage)
    }
}
