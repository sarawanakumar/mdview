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
/// Rendered (roadmap 2.2–2.6): headings with anchors, paragraphs, line
/// breaks, emphasis, strong, strikethrough, inline code, horizontal rules,
/// lists and task lists, blockquotes, code blocks, tables, inline and block
/// HTML (as text), links and bare web addresses. Front matter is hidden.
/// Images show their alt text for now (roadmap 3.3); code isn't
/// highlighted yet (M6).
public enum HTMLRenderer {
    /// Renders Markdown text: front matter hidden (spec 2.13), smart
    /// punctuation off (spec 2.15).
    public static func render(markdown: String) -> String {
        let document = Document(parsing: FrontMatter.strip(markdown), options: [.disableSmartOpts])
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
    /// How many links or images we're inside; bare web addresses aren't
    /// linked there. Counted while walking, because asking a node for its
    /// parents is slow in swift-markdown.
    private var linkDepth = 0

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

    // MARK: Code blocks (spec 2.8)

    /// `<pre><code>`; the page's CSS makes long lines scroll sideways inside
    /// the block. The language (first word of the fence's info string) is
    /// kept as a class for highlighting (roadmap M6).
    mutating func visitCodeBlock(_ code: CodeBlock) -> String {
        let language = code.language.map(Self.languageName) ?? ""
        let attribute = language.isEmpty ? "" : " class=\"language-\(language)\""
        return "<pre><code\(attribute)>\(escape(trimmingFinalNewline(code.code)))</code></pre>\n"
    }

    /// The fence's first word, lowercased, keeping only characters that are
    /// safe in a class name (letters, digits, `+`, `-`, `_`, `#`, `.`).
    static func languageName(_ infoString: String) -> String {
        let firstWord = infoString.split(whereSeparator: \.isWhitespace).first ?? ""
        return String(firstWord.lowercased().unicodeScalars.filter {
            ("a"..."z").contains($0) || ("0"..."9").contains($0) || "+-_#.".unicodeScalars.contains($0)
        }.map(Character.init))
    }

    // MARK: Tables (spec 2.9)

    /// The table sits in its own scrolling box so a wide table scrolls
    /// sideways without widening the page. Alignment is a class per cell.
    /// Rows with fewer cells than the header are padded, as on GitHub.
    mutating func visitTable(_ table: Table) -> String {
        let alignments = table.columnAlignments
        let columns = max(table.maxColumnCount, alignments.count)
        var html = "<div class=\"table\"><table>\n<thead>\n"
        html += row(Array(table.head.cells), tag: "th", columns: columns, alignments: alignments)
        html += "</thead>\n"
        let rows = Array(table.body.rows)
        if !rows.isEmpty {
            html += "<tbody>\n"
            for bodyRow in rows {
                html += row(Array(bodyRow.cells), tag: "td", columns: columns, alignments: alignments)
            }
            html += "</tbody>\n"
        }
        return html + "</table></div>\n"
    }

    private mutating func row(
        _ cells: [Table.Cell], tag: String, columns: Int, alignments: [Table.ColumnAlignment?]
    ) -> String {
        var html = "<tr>\n"
        var column = 0
        for cell in cells where column < columns {
            // A cell covered by a neighbour's span has a span of 0.
            guard cell.colspan > 0, cell.rowspan > 0 else { column += 1; continue }
            var attributes = Self.alignmentClass(column < alignments.count ? alignments[column] : nil)
            if cell.colspan > 1 { attributes += " colspan=\"\(cell.colspan)\"" }
            if cell.rowspan > 1 { attributes += " rowspan=\"\(cell.rowspan)\"" }
            html += "<\(tag)\(attributes)>\(visitChildren(of: cell))</\(tag)>\n"
            column += Int(cell.colspan)
        }
        while column < columns {
            let attributes = Self.alignmentClass(column < alignments.count ? alignments[column] : nil)
            html += "<\(tag)\(attributes)></\(tag)>\n"
            column += 1
        }
        return html + "</tr>\n"
    }

    private static func alignmentClass(_ alignment: Table.ColumnAlignment?) -> String {
        switch alignment {
        case .left: " class=\"align-left\""
        case .center: " class=\"align-center\""
        case .right: " class=\"align-right\""
        case nil: ""
        }
    }

    // MARK: Inlines

    /// Plain text, with bare web addresses turned into links (spec 2.14),
    /// except inside a link's own text.
    mutating func visitText(_ text: Text) -> String {
        guard linkDepth == 0 else { return escape(text.string) }
        var html = ""
        for segment in Autolinker.segments(in: text.string) {
            switch segment {
            case .text(let plain):
                html += escape(String(plain))
            case .link(let linkText, let url):
                html += anchor(href: url, content: escape(String(linkText)))
            }
        }
        return html
    }

    // MARK: Links (spec 2.11)

    /// A link with a safe destination becomes `<a>`; hovering shows where
    /// it goes (spec 4.5). Anything else (`javascript:`, `data:` and so on)
    /// keeps only its text. Clicks are handled by the app (roadmap 3.5).
    mutating func visitLink(_ link: Link) -> String {
        linkDepth += 1
        let content = visitChildren(of: link)
        linkDepth -= 1
        guard let destination = link.destination, Self.isSafeDestination(destination) else {
            return content
        }
        return anchor(href: destination, content: content)
    }

    /// Images show their alt text for now (roadmap 3.3).
    mutating func visitImage(_ image: Image) -> String {
        linkDepth += 1
        defer { linkDepth -= 1 }
        return visitChildren(of: image)
    }

    private func anchor(href: String, content: String) -> String {
        "<a href=\"\(escape(href))\" title=\"\(escape(href))\">\(content)</a>"
    }

    /// Relative paths, `#anchors`, and http, https, mailto and file URLs.
    static func isSafeDestination(_ destination: String) -> Bool {
        let trimmed = destination.drop(while: \.isWhitespace)
        // A scheme is letters, digits, "+", "-" or "." before the first ":",
        // and only if that ":" comes before any "/", "?" or "#".
        guard let colon = trimmed.firstIndex(of: ":"),
              !trimmed[..<colon].contains(where: { "/?#".contains($0) }) else {
            return true  // No scheme: a relative path or an anchor.
        }
        let scheme = trimmed[..<colon].lowercased()
        return ["http", "https", "mailto", "file"].contains(scheme)
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
