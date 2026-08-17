import Foundation

struct ProjectEntry: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case directory
        case file
    }

    let id: String
    let name: String
    let url: URL
    let kind: Kind
    let depth: Int
}

enum ProjectIndexer {
    private static let ignoredNames: Set<String> = [
        ".git", ".build", "target", "node_modules", ".DS_Store",
        "DerivedData", ".venv", "venv", "__pycache__", "dist", "build"
    ]

    static func discover(at root: URL, maxDepth: Int = 16, maxEntries: Int = 20_000) async -> [ProjectEntry] {
        await Task.detached(priority: .utility) {
            var entries: [ProjectEntry] = []
            walk(root.standardizedFileURL, depth: 0, maxDepth: maxDepth, maxEntries: maxEntries, entries: &entries)
            return entries
        }.value
    }

    private static func walk(
        _ directory: URL,
        depth: Int,
        maxDepth: Int,
        maxEntries: Int,
        entries: inout [ProjectEntry]
    ) {
        guard depth <= maxDepth, entries.count < maxEntries else { return }

        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isRegularFileKey, .isSymbolicLinkKey, .nameKey, .isPackageKey]
        let children: [URL]

        do {
            children = try FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(keys),
                options: []
            )
        } catch {
            return
        }

        let sorted = children.sorted { lhs, rhs in
            let leftDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rightDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            if leftDirectory != rightDirectory { return leftDirectory && !rightDirectory }
            return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
        }

        for child in sorted {
            guard entries.count < maxEntries else { return }
            let name = child.lastPathComponent
            guard !ignoredNames.contains(name) else { continue }

            let values = try? child.resourceValues(forKeys: keys)
            guard values?.isSymbolicLink != true else { continue }

            if values?.isDirectory == true {
                let normalized = child.standardizedFileURL
                entries.append(ProjectEntry(
                    id: normalized.path,
                    name: name,
                    url: normalized,
                    kind: .directory,
                    depth: depth
                ))
                if values?.isPackage != true {
                    walk(normalized, depth: depth + 1, maxDepth: maxDepth, maxEntries: maxEntries, entries: &entries)
                }
            } else if values?.isRegularFile == true {
                let normalized = child.standardizedFileURL
                entries.append(ProjectEntry(
                    id: normalized.path,
                    name: name,
                    url: normalized,
                    kind: .file,
                    depth: depth
                ))
            }
        }
    }
}
