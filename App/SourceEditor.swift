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

        textView.font = Self.font(zoom: 1)
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        // The standard find bar, above the text (spec 11.9). Not incremental:
        // with incremental searching on, Find Next stayed on the first match.
        textView.usesFindBar = true
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

    /// Find, Find Next / Previous and Use Selection for Find, done by the
    /// text view's own find bar. It reads the action from the sender's tag.
    func performFind(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.performTextFinderAction(sender)
    }

    /// The window's zoom (spec 6.7), as a scale of the text size.
    func setZoom(_ zoom: Double) {
        textView.font = Self.font(zoom: zoom)
    }

    private static func font(zoom: Double) -> NSFont {
        .monospacedSystemFont(ofSize: (NSFont.systemFontSize * zoom).rounded(), weight: .regular)
    }

    func focus(in window: NSWindow?) {
        window?.makeFirstResponder(textView)
    }

    func textDidChange(_ notification: Notification) {
        onChange?(textView.string)
    }
}
