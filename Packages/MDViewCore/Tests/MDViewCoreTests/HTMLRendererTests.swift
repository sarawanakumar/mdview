import Testing
@testable import MDViewCore

private func render(_ markdown: String) -> String {
    HTMLRenderer.render(markdown: markdown)
}

@Suite("HTMLEscaping")
struct HTMLEscapingTests {
    @Test func escapesMarkupCharacters() {
        #expect(HTMLEscaping.escape(#"<a href="x">Tom & 'Jerry'</a>"#)
            == "&lt;a href=&quot;x&quot;&gt;Tom &amp; &#39;Jerry&#39;&lt;/a&gt;")
    }

    @Test func leavesOtherTextAlone() {
        #expect(HTMLEscaping.escape("café ✓ 日本") == "café ✓ 日本")
    }
}

@Suite("Headings (2.1)")
struct HeadingTests {
    @Test func atxHeadingsKeepTheirLevel() {
        #expect(render("# One\n\n## Two\n\n###### Six\n") == "<h1 id=\"one\">One</h1>\n<h2 id=\"two\">Two</h2>\n<h6 id=\"six\">Six</h6>\n")
    }

    @Test func setextHeadings() {
        #expect(render("Title\n=====\n\nSub\n---\n") == "<h1 id=\"title\">Title</h1>\n<h2 id=\"sub\">Sub</h2>\n")
    }

    @Test func formattingInsideHeadings() {
        #expect(render("## A *b* `c`\n") == "<h2 id=\"a-b-c\">A <em>b</em> <code>c</code></h2>\n")
    }
}

@Suite("Paragraphs and line breaks (2.2)")
struct ParagraphTests {
    @Test func softBreakStaysInTheParagraph() {
        #expect(render("one\ntwo\n") == "<p>one\ntwo</p>\n")
    }

    @Test func blankLineStartsANewParagraph() {
        #expect(render("one\n\ntwo\n") == "<p>one</p>\n<p>two</p>\n")
    }

    @Test func twoTrailingSpacesMakeAHardBreak() {
        #expect(render("one  \ntwo\n") == "<p>one<br>\ntwo</p>\n")
    }

    @Test func backslashMakesAHardBreak() {
        #expect(render("one\\\ntwo\n") == "<p>one<br>\ntwo</p>\n")
    }

    @Test func emptyInputGivesEmptyBody() {
        #expect(render("") == "")
    }
}

@Suite("Emphasis (2.3)")
struct EmphasisTests {
    @Test func italicBothSyntaxes() {
        #expect(render("*a* _b_\n") == "<p><em>a</em> <em>b</em></p>\n")
    }

    @Test func boldBothSyntaxes() {
        #expect(render("**a** __b__\n") == "<p><strong>a</strong> <strong>b</strong></p>\n")
    }

    @Test func boldItalic() {
        #expect(render("***a***\n") == "<p><em><strong>a</strong></em></p>\n")
    }

    @Test func nestedEmphasis() {
        #expect(render("**a *b* c**\n") == "<p><strong>a <em>b</em> c</strong></p>\n")
    }

    @Test func strikethroughBothSyntaxes() {
        #expect(render("~~a~~ ~b~\n") == "<p><del>a</del> <del>b</del></p>\n")
    }

    @Test func thingsThatAreNotEmphasis() {
        #expect(render("2 * 3 * 4 and snake_case_name\n") == "<p>2 * 3 * 4 and snake_case_name</p>\n")
    }

    @Test func escapedAsterisks() {
        #expect(render("\\*not italic\\*\n") == "<p>*not italic*</p>\n")
    }
}

@Suite("Inline code (2.7)")
struct InlineCodeTests {
    @Test func inlineCode() {
        #expect(render("use `let x = 1` here\n") == "<p>use <code>let x = 1</code> here</p>\n")
    }

    @Test func codeKeepsCharactersLiteralAndEscaped() {
        #expect(render("`<div> &amp; **x**`\n") == "<p><code>&lt;div&gt; &amp;amp; **x**</code></p>\n")
    }

    @Test func backtickInsideDoubleBackticks() {
        #expect(render("``a ` b``\n") == "<p><code>a ` b</code></p>\n")
    }
}

@Suite("Horizontal rules (2.10)")
struct RuleTests {
    @Test(arguments: ["---", "***", "___", "- - -"])
    func ruleSyntaxes(_ rule: String) {
        #expect(render("a\n\n\(rule)\n\nb\n") == "<p>a</p>\n<hr>\n<p>b</p>\n")
    }
}

@Suite("HTML is shown, not rendered (2.12)")
struct HTMLSafetyTests {
    @Test func textIsEscaped() {
        #expect(render("1 < 2 & 3 > 2\n") == "<p>1 &lt; 2 &amp; 3 &gt; 2</p>\n")
    }

    @Test func inlineHTMLIsShownAsText() {
        let html = render("Hi <b>bold</b> <script>alert(1)</script>\n")
        #expect(html == "<p>Hi &lt;b&gt;bold&lt;/b&gt; &lt;script&gt;alert(1)&lt;/script&gt;</p>\n")
    }

    @Test func htmlBlockIsShownAsText() {
        let html = render("<div onclick=\"x()\">\nhi\n</div>\n")
        #expect(html == "<pre class=\"html-source\">&lt;div onclick=&quot;x()&quot;&gt;\nhi\n&lt;/div&gt;</pre>\n")
    }

    @Test func noTagFromTheSourceSurvives() {
        let source = """
        <img src=x onerror=alert(1)> <iframe src="https://example.com"></iframe>

        <style>body{display:none}</style>
        """
        let html = render(source)
        for tag in ["<img", "<iframe", "<style", "<script"] {
            #expect(!html.contains(tag), "\(tag) survived")
        }
    }

    @Test func entitiesAreDecodedThenEscaped() {
        #expect(render("&copy; &lt;tag&gt; &#169;\n") == "<p>© &lt;tag&gt; ©</p>\n")
    }
}

@Suite("Other text (2.15, links and images for now)")
struct OtherTextTests {
    @Test func smartPunctuationIsOff() {
        #expect(render("\"x\" 'y' -- z...\n") == "<p>&quot;x&quot; &#39;y&#39; -- z...</p>\n")
    }

    @Test func linksShowTheirTextForNow() {
        #expect(render("a [*link*](https://x.y) b\n") == "<p>a <em>link</em> b</p>\n")
    }

    @Test func imagesShowTheirAltTextForNow() {
        #expect(render("![alt text](a.png)\n") == "<p>alt text</p>\n")
    }
}

@Suite("Blocks not rendered yet")
struct NotYetRenderedTests {
    @Test(arguments: ["- a\n- b\n", "1. a\n", "> q\n", "```\ncode\n```\n", "| a |\n|---|\n| b |\n"])
    func shownAsEscapedSource(_ markdown: String) {
        #expect(render(markdown).hasPrefix("<pre class=\"not-yet-rendered\">"))
    }
}

@Suite("Plain text files (10.5)")
struct PlainTextTests {
    @Test func plainTextIsEscapedInPre() {
        #expect(HTMLRenderer.render(plainText: "# not a heading\n<b>")
            == "<pre class=\"plain-text\"># not a heading\n&lt;b&gt;</pre>\n")
    }
}
