import AppKit

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let font = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        ruleThickness = 42
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(textDidChange),
            name: NSText.didChangeNotification,
            object: textView
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification,
            object: textView.enclosingScrollView?.contentView
        )
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func textDidChange() {
        needsDisplay = true
    }

    @objc private func boundsDidChange() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else { return }

        NSColor.windowBackgroundColor.setFill()
        rect.fill()

        let visibleRect = scrollView.contentView.bounds
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        let string = textView.string as NSString
        let firstLine = lineNumber(at: characterRange.location, in: string)

        var line = firstLine
        var index = characterRange.location
        let maxIndex = min(NSMaxRange(characterRange), string.length)

        while index <= maxIndex && index < string.length {
            let lineRange = string.lineRange(for: NSRange(location: index, length: 0))
            let glyphIndex = layoutManager.glyphIndexForCharacter(at: lineRange.location)
            let fragment = layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil)
            let y = fragment.minY + textView.textContainerInset.height - visibleRect.minY
            draw(line: line, y: y)
            line += 1
            let next = NSMaxRange(lineRange)
            if next <= index { break }
            index = next
        }

        if string.length == 0 {
            draw(line: 1, y: textView.textContainerInset.height)
        }
    }

    private func lineNumber(at characterIndex: Int, in string: NSString) -> Int {
        guard characterIndex > 0 else { return 1 }
        let prefix = string.substring(to: min(characterIndex, string.length))
        return prefix.reduce(into: 1) { count, character in
            if character == "\n" { count += 1 }
        }
    }

    private func draw(line: Int, y: CGFloat) {
        let text = "\(line)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.tertiaryLabelColor,
        ]
        let size = text.size(withAttributes: attributes)
        let point = NSPoint(x: ruleThickness - size.width - 9, y: y)
        text.draw(at: point, withAttributes: attributes)
    }
}
