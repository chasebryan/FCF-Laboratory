import Foundation

struct DocumentSymbol: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable {
        case type
        case function
        case property
        case heading
    }

    let id: String
    let name: String
    let kind: Kind
    let line: Int

    init(name: String, kind: Kind, line: Int) {
        self.id = "\(line):\(kind.rawValue):\(name)"
        self.name = name
        self.kind = kind
        self.line = line
    }
}

enum SymbolIndex {
    static func symbols(in text: String, language: LanguageProfile) -> [DocumentSymbol] {
        var result: [DocumentSymbol] = []
        for (offset, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let value = String(line)
            if let symbol = symbol(in: value, language: language, line: offset + 1) {
                result.append(symbol)
            }
        }
        return result
    }

    private static func symbol(in lineText: String, language: LanguageProfile, line: Int) -> DocumentSymbol? {
        let trimmed = lineText.trimmingCharacters(in: .whitespaces)

        switch language.id {
        case .swift:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"\b(?:class|struct|enum|protocol|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"#, .type),
                (#"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)"#, .function),
                (#"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)"#, .property),
            ])
        case .rust:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"\b(?:struct|enum|trait|type|mod)\s+([A-Za-z_][A-Za-z0-9_]*)"#, .type),
                (#"\bfn\s+([A-Za-z_][A-Za-z0-9_]*)"#, .function),
            ])
        case .python:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"^class\s+([A-Za-z_][A-Za-z0-9_]*)"#, .type),
                (#"^(?:async\s+)?def\s+([A-Za-z_][A-Za-z0-9_]*)"#, .function),
            ])
        case .c, .cpp, .objectiveC:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"\b(?:class|struct|enum)\s+([A-Za-z_][A-Za-z0-9_]*)"#, .type),
            ])
        case .javascript, .typescript:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"\b(?:class|interface|type)\s+([A-Za-z_$][A-Za-z0-9_$]*)"#, .type),
                (#"\bfunction\s+([A-Za-z_$][A-Za-z0-9_$]*)"#, .function),
            ])
        case .ocaml:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"^module\s+([A-Za-z_][A-Za-z0-9_]*)"#, .type),
                (#"^let\s+(?:rec\s+)?([A-Za-z_][A-Za-z0-9_]*)"#, .function),
                (#"^type\s+([A-Za-z_][A-Za-z0-9_]*)"#, .type),
            ])
        case .markdown:
            return firstMatch(in: trimmed, line: line, patterns: [
                (#"^#{1,6}\s+(.+?)\s*$"#, .heading),
            ])
        default:
            return nil
        }
    }

    private static func firstMatch(
        in text: String,
        line: Int,
        patterns: [(String, DocumentSymbol.Kind)]
    ) -> DocumentSymbol? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for (pattern, kind) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  let nameRange = Range(match.range(at: 1), in: text) else { continue }
            return DocumentSymbol(name: String(text[nameRange]), kind: kind, line: line)
        }
        return nil
    }
}
