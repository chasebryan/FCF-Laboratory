import XCTest
@testable import FCFLaboratoryApp

final class NotebookServicesTests: XCTestCase {
    func testNativeNotebookRoundTripPreservesExecutionEvidence() throws {
        var notebook = NotebookFile.fresh(title: "Test")
        let execution = NotebookExecutionRecord(
            id: "run-1",
            startedAt: "2026-08-17T00:00:00Z",
            finishedAt: "2026-08-17T00:00:01Z",
            status: .succeeded,
            target: .centl,
            stdout: "verified",
            stderr: "",
            provenance: NotebookExecutionProvenance(
                sourceDigest: "sha256:abc",
                workingDirectory: ".",
                provider: "centl",
                command: ["/usr/bin/env", "centl"],
                hostOS: "macos",
                hostArch: "arm64"
            )
        )
        notebook.cells[1].executions.append(execution)

        let data = try JSONEncoder().encode(notebook)
        let decoded = try JSONDecoder().decode(NotebookFile.self, from: data)

        XCTAssertEqual(decoded.schemaVersion, fcfNotebookSchemaVersion)
        XCTAssertEqual(decoded.cells[1].executions, [execution])
    }

    func testFreshCellsUseExpectedTargets() {
        XCTAssertNil(NotebookCell.fresh(kind: .markdown).target)
        XCTAssertEqual(NotebookCell.fresh(kind: .code).target, .python)
        XCTAssertEqual(NotebookCell.fresh(kind: .engine).target, .centl)
        XCTAssertEqual(NotebookCell.fresh(kind: .ai).target, .openAI)
    }

    func testShellExecutionCapturesOutputAndProvenance() async throws {
        let project = FileManager.default.temporaryDirectory
            .appendingPathComponent("fcf-notebook-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: project, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: project) }

        let cell = NotebookCell(
            id: "cell-1",
            kind: .code,
            source: "printf FCF",
            target: .shell,
            executions: []
        )

        let result = await NotebookExecutionService.execute(cell: cell, projectURL: project, aiExecutor: nil)
        XCTAssertEqual(result.status, .succeeded)
        XCTAssertEqual(result.stdout, "FCF")
        XCTAssertTrue(result.provenance.sourceDigest.hasPrefix("sha256:"))
        XCTAssertEqual(result.provenance.provider, "zsh")
    }
}
