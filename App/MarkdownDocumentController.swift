import AppKit

/// Opens every file as a `MarkdownDocument`, including non-Markdown files
/// forced open with Open With → Other (spec 10.5). Must be created before
/// the app finishes launching so it becomes the shared controller.
final class MarkdownDocumentController: NSDocumentController {
    override func documentClass(forType typeName: String) -> AnyClass? {
        MarkdownDocument.self
    }

    /// File ▸ New makes a Markdown document (spec 12.1, ADR 0009).
    /// Info.plist keeps the Viewer role, so there's no default to inherit.
    override var defaultType: String? { MarkdownDocument.markdownType }
}
