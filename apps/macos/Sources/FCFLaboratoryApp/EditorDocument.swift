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
    @Published private(set) var language: LanguageProfile
    @Published private(set) var symbols: [DocumentSymbol] = []
    @Published private(set) var requestedLine: Int?

    private var savedText = ""
    private var analysisTask: Task<Void, Never>?

    init(url: URL) {
        self.url = url.standardizedFileURL
        self.language = LanguageProfile.detect(url: url)
    }

    deinit {
        analysisTask?.cancel()
    }

    func load() async {
        state = .loading

        do {
            let loaded = try await Task.detached(priority: .userInitiated) { [url] in
                try String(contentsOf: url, encoding: .utf8)
            }.value
            text = loaded
            savedText = loaded
            language = LanguageProfile.detect(url: url, contentPrefix: String(loaded.prefix(512)))
            symbols = SymbolIndex.symbols(in: loaded, language: language)
            isDirty = false
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func noteEdit(_ value: String) {
        text = value
        isDirty = value != savedText
        scheduleAnalysis(for: value)
    }

    func requestJump(to line: Int) {
        requestedLine = max(1, line)
    }

    func clearRequestedJump() {
        requestedLine = nil
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

    private func scheduleAnalysis(for value: String) {
        analysisTask?.cancel()
        let profile = language
        analysisTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(140))
            guard !Task.isCancelled else { return }
            let indexed = await Task.detached(priority: .utility) {
                SymbolIndex.symbols(in: value, language: profile)
            }.value
            guard !Task.isCancelled, let self, self.text == value else { return }
            self.symbols = indexed
        }
    }
}
