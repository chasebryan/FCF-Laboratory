import XCTest
@testable import FCFLaboratoryApp

final class FoundationServicesTests: XCTestCase {
    func testLanguageDetectionUsesExtension() {
        let url = URL(fileURLWithPath: "/tmp/kernel.rs")
        XCTAssertEqual(LanguageProfile.detect(url: url).id, .rust)
    }

    func testLanguageDetectionUsesShebang() {
        let url = URL(fileURLWithPath: "/tmp/tool")
        XCTAssertEqual(LanguageProfile.detect(url: url, contentPrefix: "#!/usr/bin/env python3\n").id, .python)
    }

    func testSwiftSymbolIndexFindsTypesAndFunctions() {
        let text = """
        struct Reactor {
            func ignite() {}
        }
        """
        let symbols = SymbolIndex.symbols(in: text, language: .profile(.swift))
        XCTAssertTrue(symbols.contains { $0.name == "Reactor" && $0.kind == .type })
        XCTAssertTrue(symbols.contains { $0.name == "ignite" && $0.kind == .function })
    }

    func testSyntaxServiceFindsSwiftKeyword() {
        let highlights = SyntaxService.highlights(in: "let value = 42", language: .profile(.swift))
        XCTAssertTrue(highlights.contains { $0.role == .keyword })
        XCTAssertTrue(highlights.contains { $0.role == .number })
    }

    func testGitHubRemoteParsesSSHAndHTTPS() {
        let ssh = GitHubRemoteService.parse("git@github.com:chasebryan/FCF-Laboratory.git")
        XCTAssertEqual(ssh?.slug, "chasebryan/FCF-Laboratory")

        let https = GitHubRemoteService.parse("https://github.com/chasebryan/FCF-Laboratory.git")
        XCTAssertEqual(https?.slug, "chasebryan/FCF-Laboratory")
    }

    func testProjectIndexerIncludesHiddenTechnicalFilesAndDeepSources() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FCFLaboratoryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let github = root.appendingPathComponent(".github/workflows", isDirectory: true)
        let deep = root.appendingPathComponent("src/a/b/c/d/e", isDirectory: true)
        try FileManager.default.createDirectory(at: github, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: deep, withIntermediateDirectories: true)
        try "name: CI\n".write(to: github.appendingPathComponent("ci.yml"), atomically: true, encoding: .utf8)
        try "fn main() {}\n".write(to: deep.appendingPathComponent("main.rs"), atomically: true, encoding: .utf8)

        let entries = await ProjectIndexer.discover(at: root, maxDepth: 16, maxEntries: 100)
        XCTAssertTrue(entries.contains { $0.name == ".github" && $0.kind == .directory })
        XCTAssertTrue(entries.contains { $0.name == "ci.yml" && $0.kind == .file })
        XCTAssertTrue(entries.contains { $0.name == "main.rs" && $0.kind == .file })
    }

    func testEditorLimitProtectsInteractionBudget() {
        XCTAssertEqual(EditorDocument.maximumEditableBytes, 32 * 1_048_576)
    }
}
