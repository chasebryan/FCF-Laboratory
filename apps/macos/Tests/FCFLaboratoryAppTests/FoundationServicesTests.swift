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
}
