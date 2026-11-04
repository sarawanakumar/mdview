import Markdown

/// Markdown → HTML body.
///
/// Roadmap 1.5: a minimal first version. Headings and paragraphs are
/// rendered; inline formatting is shown as its plain text for now. Every
/// other block is shown as escaped source in a `<pre>`, so nothing in the
/// file is lost or interpreted. Roadmap M2 renders everything properly.
public enum HTMLRenderer {
    /// Renders Markdown text. Smart punctuation is off (spec 2.15).
    public static func render(markdown: String) -> String {
        let document = Document(parsing: markdown, options: [.disableSmartOpts])
        return document.blockChildren.map(block).joined()
    }

    /// Shows a non-Markdown file as plain text (spec 10.5).
    public static func render(plainText: String) -> String {
        "<pre class=\"plain-text\">\(HTMLEscaping.escape(plainText))</pre>\n"
    }

    private static func block(_ markup: BlockMarkup) -> String {
        switch markup {
        case let heading as Heading:
            let level = min(max(heading.level, 1), 6)
            return "<h\(level)>\(inline(heading.inlineChildren))</h\(level)>\n"
        case let paragraph as Paragraph:
            return "<p>\(inline(paragraph.inlineChildren))</p>\n"
        default:
            return "<pre class=\"not-yet-rendered\">\(HTMLEscaping.escape(markup.format()))</pre>\n"
        }
    }

    private static func inline(_ children: some Sequence<InlineMarkup>) -> String {
        children.map { child -> String in
            switch child {
            case let text as Text:
                return HTMLEscaping.escape(text.string)
            case is SoftBreak:
                return "\n"
            case is LineBreak:
                return "<br>\n"
            case let container as InlineContainer:
                return inline(container.inlineChildren)
            case let leaf as PlainTextConvertibleMarkup:
                // Inline code and inline HTML: shown as text.
                return HTMLEscaping.escape(leaf.plainText)
            default:
                return HTMLEscaping.escape(child.format())
            }
        }.joined()
    }
}
