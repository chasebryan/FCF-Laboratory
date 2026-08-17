import Foundation

@MainActor
final class EditorDocument: ObservableObject, Identifiable {
    enum State: Equatable {
        case loading
        case ready
        case failed(String)
    }

    let id = UUID()
    let url: URL

    @Published var text = ""
    @Published private(set) var state: State = .loading
    @Published private(set) var isDirty = false

    private var savedText = ""

    init(url: URL) {
        self.url = url.standardizedFileURL
    }

    func load() async {
        state = .loading

        do {
            let loaded = try await Task.detached(priority: .userInitiated) { [url] in
                try String(contentsOf: url, encoding: .utf8)
            }.value
            text = loaded
            savedText = loaded
            isDirty = false
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func noteEdit(_ value: String) {
        text = value
        isDirty = value != savedText
    }

    func save() async {
        let value = text

        do {
            try await Task.detached(priority: .userInitiated) { [url] in
                try value.write(to: url, atomically: true, encoding: .utf8)
            }.value
            savedText = value
            isDirty = false
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
