import AppKit

/// One window per file (spec 6.1).
///
/// Temporary content for roadmap 1.3: the file's text in a read-only text
/// view. Roadmap 1.5 replaces it with the rendered preview.
final class DocumentWindowController: NSWindowController {
    init(document: MarkdownDocument) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        let scroll = NSTextView.scrollableTextView()
        if let textView = scroll.documentView as? NSTextView {
            textView.isEditable = false
            textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
            textView.textContainerInset = NSSize(width: 16, height: 16)
            textView.string = document.text
        }

        var views: [NSView] = []
        if document.hadInvalidBytes {
            views.append(Self.noticeBar(
                "Some of this file isn’t valid UTF-8 text, so it may not display correctly."
            ))
        }
        views.append(scroll)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        stack.alignment = .leading
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        scroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        window.contentView = stack
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// A slim notice above the content (spec 10.2).
    private static func noticeBar(_ message: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor
        label.setAccessibilityRole(.staticText)

        let bar = NSStackView(views: [label])
        bar.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        bar.setContentHuggingPriority(.required, for: .vertical)
        return bar
    }
}
