import AppKit
import SwiftUI

struct CodeEditorView: NSViewRepresentable {
    @Binding var text: String
    var language: LanguageProfile = .profile(.plainText)
    var requestedLine: Int? = nil
    var onJumpHandled: () -> Void = {}
    var onEdit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.usesFindBar = true
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.textColor = .labelColor
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 18, height: 18)
        textView.string = text
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        scrollView.documentView = textView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true
        scrollView.verticalRulerView = LineNumberRulerView(textView: textView)

        context.coordinator.applyHighlighting(to: textView)
        context.coordinator.handleRequestedJump(in: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.selectedRanges = selectedRanges
            context.coordinator.applyHighlighting(to: textView)
        }
        context.coordinator.handleRequestedJump(in: textView)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditorView

        init(parent: CodeEditorView) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.onEdit(textView.string)
            applyHighlighting(to: textView)
            textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        func handleRequestedJump(in textView: NSTextView) {
            guard let requestedLine = parent.requestedLine else { return }
            let string = textView.string as NSString
            var line = 1
            var index = 0

            while line < requestedLine && index < string.length {
                let range = string.lineRange(for: NSRange(location: index, length: 0))
                let next = NSMaxRange(range)
                if next <= index { break }
                index = next
                line += 1
            }

            let selection = NSRange(location: min(index, string.length), length: 0)
            textView.setSelectedRange(selection)
            textView.scrollRangeToVisible(selection)
            textView.window?.makeFirstResponder(textView)
            parent.onJumpHandled()
        }

        func applyHighlighting(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            let selectedRanges = textView.selectedRanges
            let fullRange = NSRange(location: 0, length: storage.length)
            let baseFont = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)

            storage.beginEditing()
            storage.setAttributes([
                .font: baseFont,
                .foregroundColor: NSColor.labelColor,
            ], range: fullRange)

            for highlight in SyntaxService.highlights(in: textView.string, language: parent.language) {
                guard NSMaxRange(highlight.range) <= storage.length else { continue }
                storage.addAttribute(.foregroundColor, value: SyntaxService.color(for: highlight.role), range: highlight.range)
            }
            storage.endEditing()
            textView.selectedRanges = selectedRanges
        }
    }
}
