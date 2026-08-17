import Foundation

struct ProjectSearchResult: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let line: Int
    let preview: String
}

enum ProjectSearch {
    static func search(
        query: String,
        entries: [ProjectEntry],
        maxResults: Int = 200,
        maxFileBytes: Int = 1_000_000
    ) async -> [ProjectSearchResult] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }

        let fileURLs = entries.filter { $0.kind == .file }.map(\.url)
        return await Task.detached(priority: .utility) {
            var results: [ProjectSearchResult] = []

            for url in fileURLs {
                guard results.count < maxResults else { break }
                guard let values = try? url.resourceValues(forKeys: [.fileSizeKey]),
                      (values.fileSize ?? 0) <= maxFileBytes,
                      let text = try? String(contentsOf: url, encoding: .utf8) else { continue }

                for (index, line) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                    guard results.count < maxResults else { break }
                    let value = String(line)
                    guard value.localizedCaseInsensitiveContains(needle) else { continue }
                    results.append(ProjectSearchResult(
                        id: "\(url.path):\(index + 1)",
                        url: url,
                        line: index + 1,
                        preview: value.trimmingCharacters(in: .whitespaces).prefix(180).description
                    ))
                }
            }

            return results
        }.value
    }
}
