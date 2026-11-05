import Testing
@testable import MDViewCore

private func render(_ markdown: String) -> String {
    HTMLRenderer.render(markdown: markdown)
}

@Suite("Code blocks (2.8)")
struct CodeBlockTests {
    @Test func fencedWithLanguage() {
        #expect(render("```swift\nlet x = 1\n```\n")
            == "<pre><code class=\"language-swift\"><span class=\"tok-keyword\">let</span> x = <span class=\"tok-number\">1</span></code></pre>\n")
    }

    @Test func fencedWithoutLanguage() {
        #expect(render("```\nplain\n```\n") == "<pre><code>plain</code></pre>\n")
    }

    @Test func tildeFence() {
        #expect(render("~~~python\nprint(1)\n~~~\n") == "<pre><code class=\"language-python\">print(<span class=\"tok-number\">1</span>)</code></pre>\n")
    }

    @Test func indentedCode() {
        #expect(render("    a\n    b\n") == "<pre><code>a\nb</code></pre>\n")
    }

    @Test func codeIsEscapedAndLiteral() {
        #expect(render("```\n<b>&amp; **x**</b>\n```\n") == "<pre><code>&lt;b&gt;&amp;amp; **x**&lt;/b&gt;</code></pre>\n")
    }

    @Test func blankLinesInsideAreKept() {
        #expect(render("```\na\n\nb\n```\n") == "<pre><code>a\n\nb</code></pre>\n")
    }

    @Test func emptyBlock() {
        #expect(render("```\n```\n") == "<pre><code></code></pre>\n")
    }

    @Test func onlyTheFirstWordOfTheInfoStringCounts() {
        #expect(render("```Swift title=\"x\"\ny\n```\n").hasPrefix("<pre><code class=\"language-swift\">"))
    }

    @Test(arguments: [("c++", "c++"), ("objective-c", "objective-c"), ("c#", "c#"), ("\"><script>", "script")])
    func languageNameIsSafe(_ info: String, _ expected: String) {
        #expect(HTMLVisitor.languageName(info) == expected)
    }

    @Test func codeInsideAQuote() {
        #expect(render("> ```\n> q\n> ```\n") == "<blockquote>\n<pre><code>q</code></pre>\n</blockquote>\n")
    }

    @Test func codeInsideAListItem() {
        #expect(render("1. item\n\n   ```json\n   {}\n   ```\n")
            == "<ol>\n<li><p>item</p>\n<pre><code class=\"language-json\">{}</code></pre>\n</li>\n</ol>\n")
    }
}

@Suite("Tables (2.9)")
struct TableTests {
    @Test func headerAndBody() {
        #expect(render("| a | b |\n|---|---|\n| 1 | 2 |\n") == """
            <div class="table"><table>
            <thead>
            <tr>
            <th>a</th>
            <th>b</th>
            </tr>
            </thead>
            <tbody>
            <tr>
            <td>1</td>
            <td>2</td>
            </tr>
            </tbody>
            </table></div>

            """)
    }

    @Test func alignment() {
        let html = render("| l | c | r | d |\n|:--|:-:|--:|---|\n| 1 | 2 | 3 | 4 |\n")
        #expect(html.contains("<th class=\"align-left\">l</th>\n<th class=\"align-center\">c</th>\n<th class=\"align-right\">r</th>\n<th>d</th>"))
        #expect(html.contains("<td class=\"align-left\">1</td>\n<td class=\"align-center\">2</td>\n<td class=\"align-right\">3</td>\n<td>4</td>"))
    }

    @Test func formattingInCells() {
        let html = render("| x |\n|---|\n| **b** `c` ~~d~~ |\n")
        #expect(html.contains("<td><strong>b</strong> <code>c</code> <del>d</del></td>"))
    }

    @Test func escapedPipe() {
        #expect(render("| x |\n|---|\n| a \\| b |\n").contains("<td>a | b</td>"))
    }

    @Test func shortRowsArePadded() {
        let html = render("| a | b | c |\n|---|---|---|\n| 1 |\n")
        #expect(html.contains("<tr>\n<td>1</td>\n<td></td>\n<td></td>\n</tr>"))
    }

    @Test func extraCellsAreDropped() {
        let html = render("| a |\n|---|\n| 1 | 2 | 3 |\n")
        #expect(html.contains("<tr>\n<td>1</td>\n</tr>"))
        #expect(!html.contains("<td>2</td>"))
    }

    @Test func headerOnly() {
        let html = render("| a |\n|---|\n")
        #expect(html.contains("</thead>\n</table></div>"))
        #expect(!html.contains("<tbody>"))
    }

    @Test func cellTextIsEscaped() {
        #expect(render("| x |\n|---|\n| <i>y</i> |\n").contains("<td>&lt;i&gt;y&lt;/i&gt;</td>"))
    }
}
