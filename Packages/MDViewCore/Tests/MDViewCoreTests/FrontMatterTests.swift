import Testing
@testable import MDViewCore

@Suite("Front matter (2.13)")
struct FrontMatterTests {
    @Test func stripsALeadingBlock() {
        #expect(FrontMatter.strip("---\ntitle: x\n---\n# Hi\n") == "# Hi\n")
    }

    @Test func dotsCanCloseIt() {
        #expect(FrontMatter.strip("---\na: 1\n...\nbody\n") == "body\n")
    }

    @Test func emptyBlock() {
        #expect(FrontMatter.strip("---\n---\nbody") == "body")
    }

    @Test func windowsLineEndingsAndTrailingSpaces() {
        #expect(FrontMatter.strip("---  \r\na: 1\r\n---\r\nbody\r\n") == "body\r\n")
    }

    @Test func unclosedBlockIsLeftAlone() {
        let text = "---\nnot closed\n"
        #expect(FrontMatter.strip(text) == text)
    }

    @Test func mustBeOnTheFirstLine() {
        let text = "\n---\na: 1\n---\nbody\n"
        #expect(FrontMatter.strip(text) == text)
    }

    @Test func onlyTheFirstBlockIsRemoved() {
        #expect(FrontMatter.strip("---\na\n---\ntext\n\n---\n\nmore\n") == "text\n\n---\n\nmore\n")
    }

    @Test func longerDashesAreNotAFence() {
        let text = "----\na\n----\n"
        #expect(FrontMatter.strip(text) == text)
    }

    @Test func fileWithoutFrontMatterIsUnchanged() {
        #expect(FrontMatter.strip("# Title\n\n---\n") == "# Title\n\n---\n")
    }

    @Test func renderedPageHidesItAndKeepsLaterRules() {
        let html = HTMLRenderer.render(markdown: "---\ntitle: Hidden\n---\n\n# Shown\n\ntext\n\n---\n\nend\n")
        #expect(html == "<h1 id=\"shown\">Shown</h1>\n<p>text</p>\n<hr>\n<p>end</p>\n")
    }
}
