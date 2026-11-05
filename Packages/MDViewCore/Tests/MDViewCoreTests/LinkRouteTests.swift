import Foundation
import Testing
@testable import MDViewCore

@Suite("What a link click does (4.1–4.4)")
struct LinkRouteTests {
    private let document = URL(fileURLWithPath: "/Users/me/Notes/readme.md")

    /// What WebKit hands us for an href on a page whose base URL is the
    /// document's folder.
    private func clicked(_ href: String) -> LinkRoute {
        let base = URL(string: "mdview-file://document/Users/me/Notes/")!
        return LinkRoute.decide(URL(string: href, relativeTo: base)!.absoluteURL, document: document)
    }

    @Test(arguments: ["https://example.com/a", "http://example.com", "mailto:me@example.com", "HTTPS://X.Y"])
    func webAndMailLinksOpenOutside(_ href: String) {
        guard case .external = clicked(href) else { Issue.record("\(href) → \(clicked(href))"); return }
    }

    @Test func relativeMarkdownFileOpensInMdview() {
        #expect(clicked("other.md") == .openMarkdown(URL(fileURLWithPath: "/Users/me/Notes/other.md"), fragment: nil))
    }

    @Test func parentFolderLinksResolve() {
        #expect(clicked("../Work/plan.md") == .openMarkdown(URL(fileURLWithPath: "/Users/me/Work/plan.md"), fragment: nil))
    }

    @Test func markdownFileWithAnchor() {
        #expect(clicked("other.md#install-steps") == .openMarkdown(URL(fileURLWithPath: "/Users/me/Notes/other.md"), fragment: "install-steps"))
    }

    @Test(arguments: ["a.markdown", "b.mdown", "c.mkd", "D.MD"])
    func allMarkdownExtensions(_ href: String) {
        guard case .openMarkdown = clicked(href) else { Issue.record("\(href) → \(clicked(href))"); return }
    }

    @Test func otherFilesOpenInTheirDefaultApp() {
        #expect(clicked("report.pdf") == .openFile(URL(fileURLWithPath: "/Users/me/Notes/report.pdf")))
        #expect(clicked("images/") == .openFile(URL(fileURLWithPath: "/Users/me/Notes/images/")))
    }

    @Test func spacesAndAccents() {
        #expect(clicked("my%20notes/caf%C3%A9.md") == .openMarkdown(URL(fileURLWithPath: "/Users/me/Notes/my notes/café.md"), fragment: nil))
    }

    @Test func anchorOnThisPageScrolls() {
        #expect(clicked("#tables-29") == .scrollInPage)
    }

    @Test func linkToThisFileWithAnchorScrolls() {
        #expect(clicked("readme.md#usage") == .scrollInPage)
    }

    @Test func linkToThisFileWithoutAnchorDoesNothing() {
        #expect(clicked("readme.md") == .ignore)
    }

    @Test func fileURLs() {
        #expect(LinkRoute.decide(URL(string: "file:///tmp/x.md#a")!, document: document) == .openMarkdown(URL(fileURLWithPath: "/tmp/x.md"), fragment: "a"))
    }

    @Test(arguments: ["ftp://x.y/a", "javascript:alert(1)", "data:text/plain,hi", "mdview-file://elsewhere/x.md"])
    func otherSchemesAreIgnored(_ href: String) {
        #expect(LinkRoute.decide(URL(string: href)!, document: document) == .ignore)
    }
}
