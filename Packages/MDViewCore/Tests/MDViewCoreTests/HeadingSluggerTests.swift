import Testing
@testable import MDViewCore

@Suite("HeadingSlugger (GitHub-style anchors, 4.3)")
struct HeadingSluggerTests {
    @Test(arguments: [
        ("Installation", "installation"),
        ("Getting Started", "getting-started"),
        ("Tables (2.9)", "tables-29"),
        ("Punctuation: \"quotes\", & ampersands, (brackets)!", "punctuation-quotes--ampersands-brackets"),
        ("snake_case and kebab-case", "snake_case-and-kebab-case"),
        ("  Leading and trailing  ", "--leading-and-trailing--"),
        ("Émigré Café", "émigré-café"),
        ("日本語の見出し", "日本語の見出し"),
        ("Emoji 🎉 party", "emoji--party"),
        ("C++ & C#", "c--c"),
        ("v1.2.3", "v123"),
        ("!!!", ""),
    ])
    func baseSlugMatchesGitHub(_ text: String, _ expected: String) {
        #expect(HeadingSlugger.baseSlug(text) == expected)
    }

    @Test func repeatsAreNumbered() {
        var slugger = HeadingSlugger()
        #expect(["Intro", "Intro", "Intro"].map { slugger.slug(for: $0) } == ["intro", "intro-1", "intro-2"])
    }

    @Test func numberingSkipsNamesAlreadyUsed() {
        var slugger = HeadingSlugger()
        let slugs = ["Foo 1", "Foo", "Foo", "Foo"].map { slugger.slug(for: $0) }
        #expect(slugs == ["foo-1", "foo", "foo-2", "foo-3"])
    }
}

@Suite("Heading anchors in HTML (2.1, 4.3)")
struct HeadingAnchorTests {
    @Test func headingsGetIDs() {
        #expect(HTMLRenderer.render(markdown: "# Hello World\n") == "<h1 id=\"hello-world\">Hello World</h1>\n")
    }

    @Test func formattingIsLeftOutOfTheID() {
        #expect(HTMLRenderer.render(markdown: "## Use *the* `cli` tool\n")
            == "<h2 id=\"use-the-cli-tool\">Use <em>the</em> <code>cli</code> tool</h2>\n")
    }

    @Test func linkTextCounts() {
        #expect(HTMLRenderer.render(markdown: "## See [docs](https://x.y)\n").hasPrefix("<h2 id=\"see-docs\">"))
    }

    @Test func duplicatesAcrossTheDocument() {
        let html = HTMLRenderer.render(markdown: "# A\n\n## A\n\n### A\n")
        #expect(html == "<h1 id=\"a\">A</h1>\n<h2 id=\"a-1\">A</h2>\n<h3 id=\"a-2\">A</h3>\n")
    }

    @Test func eachDocumentStartsCountingAgain() {
        #expect(HTMLRenderer.render(markdown: "# A\n") == HTMLRenderer.render(markdown: "# A\n"))
    }

    @Test func headingWithNoUsableCharactersGetsNoID() {
        #expect(HTMLRenderer.render(markdown: "# !!!\n") == "<h1>!!!</h1>\n")
    }

    @Test func idIsEscaped() {
        // Quotes are dropped by the slug rules, so nothing can break out of
        // the attribute.
        #expect(HTMLRenderer.render(markdown: "# a\" onclick=\"x\n") == "<h1 id=\"a-onclickx\">a&quot; onclick=&quot;x</h1>\n")
    }
}
