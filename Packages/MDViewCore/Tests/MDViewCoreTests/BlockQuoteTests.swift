import Testing
@testable import MDViewCore

private func render(_ markdown: String) -> String {
    HTMLRenderer.render(markdown: markdown)
}

@Suite("Blockquotes (2.6)")
struct BlockQuoteTests {
    @Test func simpleQuote() {
        #expect(render("> quoted\n") == "<blockquote>\n<p>quoted</p>\n</blockquote>\n")
    }

    @Test func lazyContinuationStaysInTheQuote() {
        #expect(render("> one\ntwo\n") == "<blockquote>\n<p>one\ntwo</p>\n</blockquote>\n")
    }

    @Test func twoParagraphs() {
        #expect(render("> a\n>\n> b\n") == "<blockquote>\n<p>a</p>\n<p>b</p>\n</blockquote>\n")
    }

    @Test func blankLineEndsTheQuote() {
        #expect(render("> a\n\n> b\n") == "<blockquote>\n<p>a</p>\n</blockquote>\n<blockquote>\n<p>b</p>\n</blockquote>\n")
    }

    @Test func nestedThreeLevels() {
        #expect(render("> 1\n> > 2\n> > > 3\n") == """
            <blockquote>
            <p>1</p>
            <blockquote>
            <p>2</p>
            <blockquote>
            <p>3</p>
            </blockquote>
            </blockquote>
            </blockquote>

            """)
    }

    @Test func listInsideAQuote() {
        #expect(render("> - a\n> - b\n") == "<blockquote>\n<ul>\n<li>a</li>\n<li>b</li>\n</ul>\n</blockquote>\n")
    }

    @Test func quoteInsideAListItem() {
        #expect(render("- item\n\n  > quoted\n") == "<ul>\n<li><p>item</p>\n<blockquote>\n<p>quoted</p>\n</blockquote>\n</li>\n</ul>\n")
    }

    @Test func formattingAndHeadingsInside() {
        #expect(render("> ## Title\n> **b**\n") == "<blockquote>\n<h2 id=\"title\">Title</h2>\n<p><strong>b</strong></p>\n</blockquote>\n")
    }

    @Test func htmlInsideIsStillText() {
        #expect(render("> <b>x</b>\n") == "<blockquote>\n<p>&lt;b&gt;x&lt;/b&gt;</p>\n</blockquote>\n")
    }

    @Test func emptyQuote() {
        #expect(render(">\n") == "<blockquote>\n</blockquote>\n")
    }
}
