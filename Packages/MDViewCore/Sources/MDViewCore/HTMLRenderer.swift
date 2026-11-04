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
/// Rendered so far (roadmap 2.2–2.5): headings with anchors, paragraphs,
/// line breaks, emphasis, strong, strikethrough, inline code, horizontal
/// rules, lists and task lists, blockquotes, inline and block HTML (as
/// text). Links and images show their text for now. Code blocks and tables
/// are shown as escaped source until roadmap 2.6.
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

    private var slugger = HeadingSlugger()
    /// One entry per list being rendered, innermost last: whether it's
    /// tight (its items' paragraphs are shown without paragraph spacing).
    private var tightLists: [Bool] = []

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

    /// Each heading gets a GitHub-style `id`, so `#anchor` links work
    /// (spec 4.3). A heading with no usable characters gets none.
    mutating func visitHeading(_ heading: Heading) -> String {
        let level = min(max(heading.level, 1), 6)
        let slug = slugger.slug(for: Self.text(of: heading))
        let id = slug.isEmpty ? "" : " id=\"\(escape(slug))\""
        return "<h\(level)\(id)>\(visitChildren(of: heading))</h\(level)>\n"
    }

    /// The text a reader sees in a heading: formatting removed, code kept
    /// without its backticks. This is what GitHub makes anchors from.
    static func text(of markup: any Markup) -> String {
        var text = ""
        for child in markup.children {
            switch child {
            case let plain as Text: text += plain.string
            case let code as InlineCode: text += code.code
            case let html as InlineHTML: text += html.rawHTML
            case is SoftBreak, is LineBreak: text += " "
            default: text += Self.text(of: child)
            }
        }
        return text
    }

    /// In a tight list, an item's paragraph is just its text, as on GitHub.
    mutating func visitParagraph(_ paragraph: Paragraph) -> String {
        if paragraph.parent is ListItem, tightLists.last == true {
            return visitChildren(of: paragraph) + "\n"
        }
        return "<p>\(visitChildren(of: paragraph))</p>\n"
    }

    // MARK: Lists (spec 2.4, 2.5)

    mutating func visitUnorderedList(_ list: UnorderedList) -> String {
        renderList(list, tag: "ul", start: 1)
    }

    mutating func visitOrderedList(_ list: OrderedList) -> String {
        renderList(list, tag: "ol", start: Int(list.startIndex))
    }

    private mutating func renderList(_ list: any ListItemContainer, tag: String, start: Int) -> String {
        var attributes = ""
        if start != 1 { attributes += " start=\"\(start)\"" }
        if list.listItems.contains(where: { $0.checkbox != nil }) {
            attributes += " class=\"contains-task-list\""
        }
        tightLists.append(Self.isTight(list))
        let items = visitChildren(of: list)
        tightLists.removeLast()
        return "<\(tag)\(attributes)>\n\(items)</\(tag)>\n"
    }

    /// A task item gets a read-only checkbox (spec 2.5); VoiceOver reads it
    /// as checked or not checked.
    mutating func visitListItem(_ item: ListItem) -> String {
        var content = visitChildren(of: item)
        // "<li>text</li>", but a nested block keeps its own line:
        // "<li>text\n<ul>…</ul>\n</li>".
        if Self.lastChild(of: item) is Paragraph {
            content = Self.trimmingFinalNewline(content)
        }
        guard let checkbox = item.checkbox else {
            return "<li>\(content)</li>\n"
        }
        let checked = checkbox == .checked ? " checked" : ""
        return "<li class=\"task-list-item\"><input type=\"checkbox\" disabled\(checked)> \(content)</li>\n"
    }

    /// CommonMark: a list is loose if a blank line separates two of its
    /// items, or two blocks inside one item. swift-markdown doesn't say, so
    /// we work it out from source lines.
    static func isTight(_ list: any ListItemContainer) -> Bool {
        var previousEnd: Int?
        for item in list.listItems {
            if let previousEnd, let start = item.range?.lowerBound.line, start - previousEnd > 1 {
                return false
            }
            var lastChildEnd: Int?
            for child in item.children {
                if let lastChildEnd, let start = child.range?.lowerBound.line, start - lastChildEnd > 1 {
                    return false
                }
                lastChildEnd = contentEndLine(of: child) ?? lastChildEnd
            }
            previousEnd = lastChildEnd ?? item.range?.lowerBound.line
        }
        return true
    }

    /// The last source line with content in a block. Container ranges (list
    /// items, lists, quotes) can include trailing blank lines, so follow the
    /// last child down to a block whose range is exact.
    private static func contentEndLine(of block: any Markup) -> Int? {
        if block is ListItemContainer || block is ListItem || block is BlockQuote,
           let last = lastChild(of: block) {
            return contentEndLine(of: last)
        }
        return block.range?.upperBound.line
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> String {
        "<hr>\n"
    }

    /// Spec 2.12: an HTML block is shown as its source text.
    mutating func visitHTMLBlock(_ html: HTMLBlock) -> String {
        "<pre class=\"html-source\">\(escape(trimmingFinalNewline(html.rawHTML)))</pre>\n"
    }

    /// Spec 2.6: quotes can hold any blocks, including other quotes.
    mutating func visitBlockQuote(_ quote: BlockQuote) -> String {
        "<blockquote>\n\(visitChildren(of: quote))</blockquote>\n"
    }

    // Not rendered yet: shown as escaped source (roadmap 2.6).
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
        Self.trimmingFinalNewline(text)
    }

    private static func lastChild(of markup: any Markup) -> (any Markup)? {
        markup.childCount > 0 ? markup.child(at: markup.childCount - 1) : nil
    }

    private static func trimmingFinalNewline(_ text: String) -> String {
        text.hasSuffix("\n") ? String(text.dropLast()) : text
    }
}
