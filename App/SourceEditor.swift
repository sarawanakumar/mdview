import AppKit

/// Edit mode's plain-text editor for a document's source (spec 11.3,
/// ADR 0008). Made the first time a window switches to edit mode, so
/// opening a file never pays for it (spec 11.2).
@MainActor
final class SourceEditor: NSViewController, NSTextViewDelegate {
    /// Called after every change, with the new text.
    var onChange: ((String) -> Void)?

    private let textView: NSTextView

    init(text: String) {
        let scrollView = NSTextView.scrollableTextView()
        // scrollableTextView always makes an NSTextView.
        textView = scrollView.documentView as? NSTextView ?? NSTextView()
        super.init(nibName: nil, bundle: nil)
        view = scrollView

        textView.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        // What's typed is what's saved (spec 11.3).
        textView.smartInsertDeleteEnabled = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isAutomaticLinkDetectionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextCompletionEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.setAccessibilityLabel("Markdown source")

        textView.string = text
        textView.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    var text: String { textView.string }

    /// Replaces the text, for example after the file was reloaded from
    /// disk. The cursor stays as close to where it was as the new text
    /// allows. Does nothing if the text is the same.
    func setText(_ text: String) {
        guard text != textView.string else { return }
        let selection = textView.selectedRange()
        textView.string = text
        let length = (text as NSString).length
        textView.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
    }

    func focus(in window: NSWindow?) {
        window?.makeFirstResponder(textView)
    }

    func textDidChange(_ notification: Notification) {
        onChange?(textView.string)
    }
}
