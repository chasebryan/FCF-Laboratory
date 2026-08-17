import AppKit
import Foundation

enum SyntaxRole: Hashable {
    case keyword
    case string
    case comment
    case number
    case type
}

struct SyntaxHighlight: Hashable {
    let range: NSRange
    let role: SyntaxRole
}

enum SyntaxService {
    static func highlights(in text: String, language: LanguageProfile) -> [SyntaxHighlight] {
        guard !text.isEmpty else { return [] }
        let fullRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var result: [SyntaxHighlight] = []

        for pattern in patterns(for: language.id) {
            guard let expression = try? NSRegularExpression(pattern: pattern.expression, options: pattern.options) else { continue }
            for match in expression.matches(in: text, options: [], range: fullRange) {
                result.append(SyntaxHighlight(range: match.range, role: pattern.role))
            }
        }

        return result
    }

    static func color(for role: SyntaxRole) -> NSColor {
        switch role {
        case .keyword: return .systemPurple
        case .string: return .systemRed
        case .comment: return .secondaryLabelColor
        case .number: return .systemBlue
        case .type: return .systemTeal
        }
    }

    private struct Pattern {
        let expression: String
        let role: SyntaxRole
        var options: NSRegularExpression.Options = []
    }

    private static func patterns(for language: LanguageID) -> [Pattern] {
        let strings = Pattern(expression: #"\"(?:\\.|[^\"\\])*\"|'(?:\\.|[^'\\])*'"#, role: .string)
        let numbers = Pattern(expression: #"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, role: .number)

        switch language {
        case .swift:
            return [
                Pattern(expression: #"//.*$|/\*[\s\S]*?\*/"#, role: .comment, options: [.anchorsMatchLines]),
                strings,
                Pattern(expression: #"\b(?:actor|as|associatedtype|async|await|break|case|catch|class|continue|default|defer|do|else|enum|extension|fallthrough|false|fileprivate|for|func|guard|if|import|in|init|inout|internal|is|let|nil|open|operator|private|protocol|public|repeat|required|return|self|some|static|struct|subscript|super|switch|throw|throws|true|try|typealias|var|where|while)\b"#, role: .keyword),
                Pattern(expression: #"\b[A-Z][A-Za-z0-9_]*\b"#, role: .type), numbers,
            ]
        case .rust:
            return [
                Pattern(expression: #"//.*$|/\*[\s\S]*?\*/"#, role: .comment, options: [.anchorsMatchLines]), strings,
                Pattern(expression: #"\b(?:as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while)\b"#, role: .keyword),
                Pattern(expression: #"\b[A-Z][A-Za-z0-9_]*\b"#, role: .type), numbers,
            ]
        case .python:
            return [
                Pattern(expression: #"#.*$"#, role: .comment, options: [.anchorsMatchLines]), strings,
                Pattern(expression: #"\b(?:and|as|assert|async|await|break|class|continue|def|del|elif|else|except|False|finally|for|from|global|if|import|in|is|lambda|None|nonlocal|not|or|pass|raise|return|True|try|while|with|yield)\b"#, role: .keyword), numbers,
            ]
        case .c, .cpp, .objectiveC, .javascript, .typescript:
            return [
                Pattern(expression: #"//.*$|/\*[\s\S]*?\*/"#, role: .comment, options: [.anchorsMatchLines]), strings,
                Pattern(expression: #"\b(?:auto|break|case|class|const|continue|default|delete|do|else|enum|export|extends|false|for|function|if|import|interface|let|namespace|new|null|private|protected|public|return|static|struct|switch|template|this|throw|true|try|type|typeof|undefined|using|var|void|while)\b"#, role: .keyword),
                Pattern(expression: #"\b[A-Z][A-Za-z0-9_]*\b"#, role: .type), numbers,
            ]
        case .json, .toml, .yaml:
            return [strings, Pattern(expression: #"#.*$"#, role: .comment, options: [.anchorsMatchLines]), numbers]
        case .markdown:
            return [Pattern(expression: #"^#{1,6}\s+.*$"#, role: .keyword, options: [.anchorsMatchLines]), Pattern(expression: #"`[^`]+`"#, role: .string)]
        case .shell:
            return [Pattern(expression: #"#.*$"#, role: .comment, options: [.anchorsMatchLines]), strings, Pattern(expression: #"\b(?:case|do|done|elif|else|esac|fi|for|function|if|in|then|until|while)\b"#, role: .keyword), numbers]
        case .ocaml:
            return [Pattern(expression: #"\(\*[\s\S]*?\*\)"#, role: .comment), strings, Pattern(expression: #"\b(?:and|as|assert|begin|class|constraint|do|done|downto|else|end|exception|external|false|for|fun|function|functor|if|in|include|inherit|initializer|lazy|let|match|method|module|mutable|new|object|of|open|private|rec|sig|struct|then|to|true|try|type|val|virtual|when|while|with)\b"#, role: .keyword), numbers]
        case .centl, .plainText:
            return []
        }
    }
}
