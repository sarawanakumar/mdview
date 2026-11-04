import Markdown

/// Markdown → HTML body (spec section 2).
///
/// Walks swift-markdown's tree with our own visitor rather than the
/// package's built-in formatter, because we need escaping, heading anchors,
/// code highlighting and image placeholders (architecture.md).
///
/// Everything that comes from the file is escaped: text, code, and any HTML
/// in the source, which is shown as text and never becomes markup
/// (spec 2.12).
///
/// Rendered so far (roadmap 2.2): headings, paragraphs, line breaks,
/// emphasis, strong, strikethrough, inline code, horizontal rules, inline
/// and block HTML (as text). Links and images show their text for now.
/// Lists, quotes, code blocks and tables are shown as escaped source until
/// roadmap 2.4–2.6.
public enum HTMLRenderer {
    /// Renders Markdown text. Smart punctuation is off (spec 2.15).
    public static func render(markdown: String) -> String {
        let document = Document(parsing: markdown, options: [.disableSmartOpts])
        var visitor = HTMLVisitor()
        return visitor.visit(document)
    }

    /// Shows a non-Markdown file as plain text (spec 10.5).
    public static func render(plainText: String) -> String {
        "<pre class=\"plain-text\">\(HTMLEscaping.escape(plainText))</pre>\n"
    }
}

struct HTMLVisitor: MarkupVisitor {
    typealias Result = String

    // MARK: Containers

    mutating func defaultVisit(_ markup: any Markup) -> String {
        visitChildren(of: markup)
    }

    private mutating func visitChildren(of markup: any Markup) -> String {
        var html = ""
        for child in markup.children {
            html += visit(child)
        }
        return html
    }

    // MARK: Blocks

    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        return "<h\(level)>\(visitChildren(of: heading))</h\(level)>\n"
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        "<p>\(visitChildren(of: paragraph))</p>\n"
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    /// Spec 2.12: an HTML block is shown as its source text.
    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        "<pre class=\"html-source\">\(escape(trimmingFinalNewline(html.rawHTML)))</pre>\n"
    }

    // Not rendered yet: shown as escaped source (roadmap 2.4–2.6).
    mutating func visitUnorderedList(_ list: UnorderedList) -> String { notYetRendered(list) }
    mutating func visitOrderedList(_ list: OrderedList) -> String { notYetRendered(list) }
    mutating func visitBlockQuote(_ quote: BlockQuote) -> String { notYetRendered(quote) }
    mutating func visitCodeBlock(_ code: CodeBlock) -> String { notYetRendered(code) }
    mutating func visitTable(_ table: Table) -> String { notYetRendered(table) }

    private func notYetRendered(_ markup: any Markup) -> String {
        "<pre class=\"not-yet-rendered\">\(escape(markup.format()))</pre>\n"
    }

    // MARK: Inlines

    mutating func visitText(_ text: Text) -> String {
        escape(text.string)
    }

    /// A line break inside a paragraph is just a space when shown
    /// (spec 2.2); keeping it as a newline in the HTML does that.
    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> String {
        "\n"
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> String {
        "<br>\n"
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> String {
        "<em>\(visitChildren(of: emphasis))</em>"
    }

    mutating func visitStrong(_ strong: Strong) -> String {
        "<strong>\(visitChildren(of: strong))</strong>"
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> String {
        "<del>\(visitChildren(of: strikethrough))</del>"
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> String {
        "<code>\(escape(inlineCode.code))</code>"
    }

    /// Spec 2.12: inline HTML is shown as its text.
    mutating func visitInlineHTML(_ html: InlineHTML) -> String {
        escape(html.rawHTML)
    }

    // MARK: Helpers

    private func escape(_ text: String) -> String {
        HTMLEscaping.escape(text)
    }

    private func trimmingFinalNewline(_ text: String) -> String {
        text.hasSuffix("\n") ? String(text.dropLast()) : text
    }
}
