import AppKit
import SwiftUI

struct TerminalView: View {
    @ObservedObject var session: TerminalSession

    var body: some View {
        Group {
            if let failure = session.failureMessage {
                VStack(spacing: 8) {
                    Text("Unable to start terminal").font(.system(size: 14, weight: .medium))
                    Text(failure).font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                    Button("Try Again") { session.start() }.buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TerminalAppKitView(session: session)
            }
        }
    }
}

private struct TerminalAppKitView: NSViewRepresentable {
    @ObservedObject var session: TerminalSession

    func makeNSView(context: Context) -> TerminalScrollView {
        let view = TerminalScrollView()
        view.terminalTextView.sendBytes = { [weak session] data in Task { @MainActor in session?.send(data) } }
        view.onResize = { [weak session] columns, rows in Task { @MainActor in session?.resize(columns: columns, rows: rows) } }
        return view
    }

    func updateNSView(_ nsView: TerminalScrollView, context: Context) {
        nsView.terminalTextView.render(session.output)
        nsView.terminalTextView.sendBytes = { [weak session] data in Task { @MainActor in session?.send(data) } }
        nsView.onResize = { [weak session] columns, rows in Task { @MainActor in session?.resize(columns: columns, rows: rows) } }
    }
}

@MainActor
private final class TerminalScrollView: NSScrollView {
    let terminalTextView = TerminalTextView()
    var onResize: ((Int, Int) -> Void)?
    private var lastGrid = (columns: 0, rows: 0)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        borderType = .noBorder
        hasVerticalScroller = true
        hasHorizontalScroller = false
        autohidesScrollers = true
        terminalTextView.minSize = NSSize(width: 0, height: 0)
        terminalTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        terminalTextView.isVerticallyResizable = true
        terminalTextView.isHorizontallyResizable = false
        terminalTextView.autoresizingMask = NSView.AutoresizingMask.width
        terminalTextView.textContainer?.widthTracksTextView = true
        terminalTextView.textContainerInset = NSSize(width: 16, height: 14)
        documentView = terminalTextView
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        guard let font = terminalTextView.font else { return }
        let cellWidth = max(1, ("W" as NSString).size(withAttributes: [.font: font]).width)
        let lineHeight = max(1, terminalTextView.layoutManager?.defaultLineHeight(for: font) ?? 15)
        let columns = max(20, Int((contentView.bounds.width - 32) / cellWidth))
        let rows = max(4, Int((contentView.bounds.height - 28) / lineHeight))
        guard columns != lastGrid.columns || rows != lastGrid.rows else { return }
        lastGrid = (columns, rows)
        onResize?(columns, rows)
    }
}

@MainActor
private final class TerminalTextView: NSTextView {
    var sendBytes: ((Data) -> Void)?
    convenience init() { self.init(frame: .zero, textContainer: nil) }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        isEditable = false
        isSelectable = true
        isRichText = false
        drawsBackground = false
        font = NSFont.monospacedSystemFont(ofSize: 12.5, weight: .regular)
        textColor = .labelColor
        selectedTextAttributes = [.backgroundColor: NSColor.selectedTextBackgroundColor, .foregroundColor: NSColor.selectedTextColor]
    }

    func render(_ value: String) {
        guard string != value else { return }
        string = value
        scrollToEndOfDocument(nil)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers?.lowercased() ?? ""
        if flags.contains(.command) {
            if key == "c", selectedRange().length > 0 { copy(nil); return }
            if key == "v" { paste(nil); return }
            super.keyDown(with: event)
            return
        }
        if flags.contains(.control), let scalar = key.unicodeScalars.first, scalar.value >= 0x40, scalar.value <= 0x7F {
            sendBytes?(Data([UInt8(scalar.value & 0x1F)])); return
        }
        switch event.keyCode {
        case 36: sendBytes?(Data([0x0D]))
        case 48: sendBytes?(Data([0x09]))
        case 51: sendBytes?(Data([0x7F]))
        case 53: sendBytes?(Data([0x1B]))
        case 123: sendBytes?(Data("\u{1B}[D".utf8))
        case 124: sendBytes?(Data("\u{1B}[C".utf8))
        case 125: sendBytes?(Data("\u{1B}[B".utf8))
        case 126: sendBytes?(Data("\u{1B}[A".utf8))
        case 115: sendBytes?(Data("\u{1B}[H".utf8))
        case 119: sendBytes?(Data("\u{1B}[F".utf8))
        default:
            if let characters = event.characters, !characters.isEmpty { sendBytes?(Data(characters.utf8)) }
        }
    }

    override func paste(_ sender: Any?) {
        if let value = NSPasteboard.general.string(forType: .string), !value.isEmpty { sendBytes?(Data(value.utf8)) }
    }
}
