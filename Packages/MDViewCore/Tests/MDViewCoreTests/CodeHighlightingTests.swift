import Testing
@testable import MDViewCore

private func render(_ markdown: String) -> String {
    HTMLRenderer.render(markdown: markdown)
}

@Suite("Code blocks are coloured by language tag (7.1, 7.4)")
struct CodeHighlightingTests {
    /// Spec 7.1's tags, each with code that has a keyword.
    @Test(arguments: [
        ("swift", "let"), ("python", "def"), ("py", "def"), ("javascript", "const"), ("js", "const"), ("jsx", "const"),
        ("typescript", "interface"), ("ts", "interface"), ("tsx", "interface"), ("sh", "echo"), ("bash", "echo"),
        ("zsh", "echo"), ("shell", "echo"), ("json", "true"), ("yaml", "true"), ("yml", "true"), ("css", "auto"),
    ])
    func everyListedTagIsColoured(_ tag: String, _ keyword: String) {
        let html = render("```\(tag)\n\(keyword) x\n```\n")
        #expect(html.contains("<span class=\"tok-keyword\">\(keyword)</span>"), "\(tag)")
    }

    @Test func htmlTagIsColoured() {
        #expect(render("```html\n<div class=\"x\"></div>\n```\n").contains("<span class=\"tok-keyword\">div</span>"))
    }

    @Test(arguments: ["Swift", "PYTHON", "Js", "YML"])
    func tagCaseDoesNotMatter(_ tag: String) {
        #expect(render("```\(tag)\nx = 1\n```\n").contains("tok-number"))
    }

    @Test func relativesUseTheSameRules() {
        for (tag, keyword) in [("mjs", "const"), ("cjs", "const"), ("jsonc", "null"), ("htm", "p"), ("xml", "item")] {
            let code = tag == "htm" || tag == "xml" ? "<\(keyword)></\(keyword)>" : "\(keyword) x"
            #expect(render("```\(tag)\n\(code)\n```\n").contains("tok-keyword\">\(keyword)<"), "\(tag)")
        }
    }

    @Test(arguments: ["```\nlet x = 1\n```\n", "```text\nlet x = 1\n```\n", "```cobol\nlet x = 1\n```\n", "    let x = 1\n"])
    func untaggedAndUnknownStayPlain(_ markdown: String) {
        let html = render(markdown)
        #expect(!html.contains("tok-"))
        #expect(html.contains(">let x = 1</code>"))
    }

    @Test func unknownTagIsStillEscaped() {
        #expect(render("```cobol\n<b>&\n```\n").contains("&lt;b&gt;&amp;"))
    }

    @Test func inlineCodeIsNeverColoured() {
        #expect(!render("Use `let x = 1` here.\n").contains("tok-"))
    }

    @Test func codeInListsAndQuotesIsColoured() {
        #expect(render("- item\n\n  ```js\n  const a = 1\n  ```\n").contains("tok-keyword\">const<"))
        #expect(render("> ```py\n> def f(): pass\n> ```\n").contains("tok-keyword\">def<"))
    }

    @Test func onlyTheFirstWordOfTheInfoStringPicksTheLanguage() {
        #expect(render("```swift title=\"x.swift\"\nlet a = 1\n```\n").contains("tok-keyword\">let<"))
    }
}
