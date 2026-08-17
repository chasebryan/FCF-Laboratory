import Foundation

struct LaboratoryObject: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case source
        case notebook
        case document
        case paper
        case dataset
        case experiment
        case terminal
        case git
        case github
        case ai
        case engine
        case other
    }

    let id: UUID
    var title: String
    var kind: Kind
    var url: URL?

    init(id: UUID = UUID(), title: String, kind: Kind, url: URL? = nil) {
        self.id = id
        self.title = title
        self.kind = kind
        self.url = url
    }
}

@MainActor
final class WorkspaceSession: ObservableObject {
    @Published private(set) var projectURL: URL?
    @Published private(set) var objects: [LaboratoryObject] = []
    @Published var activeObjectID: LaboratoryObject.ID?
    @Published private(set) var recentProjects: [URL] = []

    private let defaults = UserDefaults.standard
    private let recentProjectsKey = "FCFLaboratory.RecentProjects"

    init() {
        restoreRecentProjects()
    }

    var activeObject: LaboratoryObject? {
        guard let activeObjectID else { return nil }
        return objects.first { $0.id == activeObjectID }
    }

    func openProject(_ url: URL) {
        projectURL = url.standardizedFileURL
        objects.removeAll(keepingCapacity: true)
        activeObjectID = nil
        rememberProject(url)
    }

    func openObject(_ object: LaboratoryObject) {
        if let existing = objects.first(where: { $0.url == object.url && object.url != nil }) {
            activeObjectID = existing.id
            return
        }
        objects.append(object)
        activeObjectID = object.id
    }

    func closeObject(_ id: LaboratoryObject.ID) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeObjectID == id
        objects.remove(at: index)

        if wasActive {
            if objects.indices.contains(index) {
                activeObjectID = objects[index].id
            } else {
                activeObjectID = objects.last?.id
            }
        }
    }

    private func rememberProject(_ url: URL) {
        let standardized = url.standardizedFileURL
        recentProjects.removeAll { $0.standardizedFileURL == standardized }
        recentProjects.insert(standardized, at: 0)
        recentProjects = Array(recentProjects.prefix(8))
        defaults.set(recentProjects.map(\.path), forKey: recentProjectsKey)
    }

    private func restoreRecentProjects() {
        let paths = defaults.stringArray(forKey: recentProjectsKey) ?? []
        recentProjects = paths.map { URL(fileURLWithPath: $0, isDirectory: true) }
    }
}
