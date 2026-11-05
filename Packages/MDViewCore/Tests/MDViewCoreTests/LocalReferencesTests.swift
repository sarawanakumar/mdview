import Foundation
import Testing
@testable import MDViewCore

@Suite("Local references (9.5)")
struct LocalReferencesTests {
    private let document = URL(fileURLWithPath: "/Users/me/Notes/readme.md")

    // MARK: Collected by the renderer

    @Test func imagesAndLinksAreCollectedInOrderWithoutRepeats() {
        let page = HTMLRenderer.renderPage(markdown: """
            ![a](img/a.png) [doc](other.md) ![again](img/a.png) [sec](other.md#part)

            [web](https://x.y) [mail](mailto:a@b.c) [anchor](#top) ![remote](https://x.y/r.png)
            [abs](/tmp/x.md) [file](file:///tmp/y.md) [bad](javascript:alert(1))
            """)
        #expect(page.localReferences == ["img/a.png", "other.md", "other.md#part", "/tmp/x.md", "file:///tmp/y.md"])
    }

    @Test func noReferencesInPlainText() {
        #expect(HTMLRenderer.renderPage(markdown: "Just text, https://example.com and `img/a.png`.\n").localReferences.isEmpty)
    }

    @Test func elementsFixtureReferences() throws {
        let page = HTMLRenderer.renderPage(markdown: try Fixtures.text("elements.md"))
        #expect(page.localReferences == ["other.md", "other.md#section", "images/sample.png"])
    }

    // MARK: Resolving

    @Test(arguments: [
        ("img/a.png", "/Users/me/Notes/img/a.png"),
        ("./img/a.png", "/Users/me/Notes/img/a.png"),
        ("../shared/b.png", "/Users/me/shared/b.png"),
        ("img/a%20b.png", "/Users/me/Notes/img/a b.png"),
        ("img/a b.png", "/Users/me/Notes/img/a b.png"),
        ("other.md#section", "/Users/me/Notes/other.md"),
        ("other.md?x=1", "/Users/me/Notes/other.md"),
        ("/tmp/x.md", "/tmp/x.md"),
        ("file:///tmp/y%20z.md", "/tmp/y z.md"),
        ("café/é.png", "/Users/me/Notes/café/é.png"),
    ])
    func resolve(_ reference: String, _ expected: String) throws {
        let url = try #require(LocalReferences.resolve(reference, relativeTo: document))
        #expect(url.path(percentEncoded: false) == expected)
    }

    @Test(arguments: ["#only-a-fragment", "", "   "])
    func nothingToResolve(_ reference: String) {
        #expect(LocalReferences.resolve(reference, relativeTo: document) == nil)
    }

    // MARK: Suggested folder

    @Test func filesBesideTheDocumentSuggestItsFolder() {
        let folder = LocalReferences.suggestedFolder(for: document, needing: [
            URL(fileURLWithPath: "/Users/me/Notes/img/a.png"),
            URL(fileURLWithPath: "/Users/me/Notes/other.md"),
        ])
        #expect(folder.path(percentEncoded: false).hasSuffix("/Users/me/Notes/") || folder.path(percentEncoded: false) == "/Users/me/Notes")
    }

    @Test func fileAboveSuggestsTheCommonFolder() {
        let folder = LocalReferences.suggestedFolder(for: document, needing: [URL(fileURLWithPath: "/Users/me/shared/b.png")])
        #expect(folder.standardizedFileURL.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/")) == "Users/me")
    }

    @Test func unrelatedPlaceSuggestsRoot() {
        let folder = LocalReferences.suggestedFolder(for: document, needing: [URL(fileURLWithPath: "/tmp/x.md")])
        #expect(folder.path(percentEncoded: false) == "/")
    }
}
