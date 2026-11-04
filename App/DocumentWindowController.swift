import AppKit

/// One window per file (spec 6.1): an optional notice bar above the
/// rendered preview.
final class DocumentWindowController: NSWindowController {
    private let preview = PreviewController()

    /// Where the next window's top-left corner goes, so several open files
    /// fan out instead of stacking exactly on top of each other.
    private static var cascadePoint = NSPoint.zero

    init(document: MarkdownDocument) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)

        var views: [NSView] = []
        if document.hadInvalidBytes {
            views.append(Self.noticeBar(
                "Some of this file isn’t valid UTF-8 text, so it may not display correctly."
            ))
        }
        views.append(preview.view)

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.spacing = 0
        stack.distribution = .fill
        stack.alignment = .leading
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        preview.view.setContentHuggingPriority(.defaultLow, for: .vertical)
        window.contentView = stack
        if Self.cascadePoint == .zero { window.center() }
        Self.cascadePoint = window.cascadeTopLeft(from: Self.cascadePoint)

        preview.show(document)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    /// A slim notice above the content (spec 10.2).
    private static func noticeBar(_ message: String) -> NSView {
        let label = NSTextField(wrappingLabelWithString: message)
        label.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        label.textColor = .secondaryLabelColor

        let bar = NSStackView(views: [label])
        bar.edgeInsets = NSEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        bar.setContentHuggingPriority(.required, for: .vertical)
        return bar
    }
}
